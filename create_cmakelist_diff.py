import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple

import requests

RE_DATE = re.compile(r"\d{8}")


def validate_file(arg):
    if (filepath := Path(arg).expanduser()).is_file():
        return filepath
    else:
        raise FileNotFoundError(arg)


def get_openstudio_cmakelist():
    r = requests.get("https://raw.githubusercontent.com/NREL/OpenStudio/develop/CMakeLists.txt")
    r.raise_for_status()
    cmake_lines = r.text.splitlines()
    return cmake_lines


def read_md5sums(
    md5_file: Optional[Path] = None, tag_name: Optional[str] = None, org_name: Optional[str] = None
) -> dict:
    assert md5_file is not None or (tag_name is not None and org_name is not None)
    if md5_file is not None:
        print(f"Reading from {md5_file}")
        md5sums_lines = md5_file.read_text().splitlines()
    else:
        url = f"https://github.com/{org_name}/openstudio-gems/releases/download/{tag_name}/md5sums.txt"
        print(f"Trying to read from release at '{url}'")
        r = requests.get(url)
        r.raise_for_status()
        md5sums_lines = r.text.splitlines()

    md5sums = {}
    for x in md5sums_lines:
        md5sha, zip_name = x.split("  ")
        md5sums[RE_DATE.sub("*", zip_name)] = {"name": zip_name, "md5sha": md5sha}
    return md5sums


def get_block_location(cmake_lines: List[str]) -> Tuple[int, int]:
    start_i = None
    end_i = None
    for i, line in enumerate(cmake_lines):
        if start_i is None and "OPENSTUDIO_GEMS_BASEURL" in line:
            start_i = i
            continue
        if start_i is not None:
            if "OPENSTUDIO_GEMS_ZIP_LOCAL_PATH" in line:
                end_i = i
                break
    assert start_i is not None and end_i is not None
    return [start_i, end_i]


def create_new_cmakelists(cmake_lines: List[str], md5sums: dict, tag_name: str, org_name: str) -> List[str]:
    # Make a copy
    cmake_mod_lines = cmake_lines[:]

    start_i, end_i = get_block_location(cmake_lines=cmake_lines)
    for i, line in enumerate(cmake_mod_lines):
        if i < start_i or i > end_i:
            continue
        if "OPENSTUDIO_GEMS_BASEURL" in line and "github" in line:
            pre, _, post = line.split('"')
            download_url = f"https://github.com/{org_name}/openstudio-gems/releases/download/{tag_name}"
            cmake_mod_lines[i] = f'{pre}"{download_url}"{post}'
        if "set(OPENSTUDIO_GEMS_ZIP_FILENAME" in line:
            zip_name = line.split('"')[1]
            lookup = RE_DATE.sub("*", zip_name)
            if lookup not in md5sums:
                zip_name = None
                continue
            d = md5sums[lookup]
            cmake_mod_lines[i] = line.replace(zip_name, d["name"])
            sha_line = cmake_mod_lines[i + 1]
            assert "set(OPENSTUDIO_GEMS_ZIP_EXPECTED_MD5" in sha_line
            old_sha = sha_line.split('"')[1]
            cmake_mod_lines[i + 1] = sha_line.replace(old_sha, d["md5sha"])
    return cmake_mod_lines


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create an OpenStudio CMakeLists.txt with updated gems")

    parser.add_argument("--tag-name", help="Use a specific tag name")
    parser.add_argument(
        "--md5-file",
        type=validate_file,
        help="Path to a md5sum.txt on disk, will download it from an existing release otherwise",
    )
    parser.add_argument(
        "--org-name",
        type=str,
        default="NREL",
        help="Path to a md5sum.txt on disk, will download it from an existing release otherwise",
    )

    args = parser.parse_args()
    tag_name = args.tag_name
    if tag_name is None:
        if "TAG_NAME" not in os.environ:
            raise ValueError("Specify --tag-name TAG_NAME or set it in environment")
        tag_name = os.environ["TAG_NAME"]
        print(f"You did not specify --tag-name, grabbing it from environment variable TAG_NAME='{tag_name}'")
    org_name = args.org_name

    md5sums = read_md5sums(md5_file=args.md5_file, tag_name=tag_name, org_name=org_name)
    cmake_lines = get_openstudio_cmakelist()
    cmake_mod_lines = create_new_cmakelists(
        cmake_lines=cmake_lines, md5sums=md5sums, tag_name=tag_name, org_name=org_name
    )
    diff_dir = Path(".tmp_diff")
    if diff_dir.exists():
        shutil.rmtree(diff_dir)
    diff_dir.mkdir()
    ori_path = diff_dir / "CMakeLists_ori.txt"
    ori_path.write_text("\n".join(cmake_lines))
    new_path = diff_dir / "CMakeLists_new.txt"
    new_path.write_text("\n".join(cmake_mod_lines))

    print("{:=^80s}".format(" Diff "))
    r = subprocess.run(
        ["diff", "-u", str(ori_path), str(new_path)], stdout=subprocess.PIPE, encoding="utf-8", universal_newlines=True
    )
    unified_diff = r.stdout
    unified_diff = unified_diff.replace(str(ori_path), "CMakeLists.txt").replace(str(new_path), "CMakeLists.txt")
    print(unified_diff)
    print("=" * 80)
    (diff_dir / "CMakeLists.txt.patch").write_text(unified_diff)

    print("\n\n")
    print("{:=^80s}".format(" For Copy Pasting "))
    start_i, end_i = get_block_location(cmake_lines=cmake_lines)
    print("\n".join(cmake_mod_lines[start_i:end_i]))
