import os

from conan import ConanFile
from conan.tools.env import Environment, VirtualBuildEnv
from conan.tools.gnu import PkgConfigDeps
from conan.tools.microsoft import is_msvc, VCVars


class GemsRecipe(ConanFile):
    settings = "os", "compiler", "build_type", "arch"

    def build_requirements(self):
        if is_msvc(self):
            self.tool_requires("ruby/3.2.2")
        if not self.conf.get('tools.gnu:pkg_config', check_type=str):
            self.tool_requires('pkgconf/2.2.0')
        self.tool_requires("sqlite3/3.47.0")

    def generate(self):
        venv = VirtualBuildEnv(self)
        venv.generate()

        # For windows to find the sqlite3
        deps = PkgConfigDeps(self)
        # tool_requires don't generate .pc files
        deps.build_context_activated = ["sqlite3"]
        deps.generate()

        env = Environment()
        env.define("GEM_HOME", os.path.abspath("gems"))
        env.define("GEM_PATH", os.path.abspath("gems"))
        # TODO: consider just comitting the ./bundle/config file
        env.define("BUNDLE_PATH", "./openstudio-gems")
        env.define("BUNDLE_WITHOUT", "test")
        # env.define("BUNDLE_NO_PRUNE", "true")
        env.define("BUNDLE_CACHE_ALL", "true")
        # env.define("BUNDLE_DISABLE_CHECKSUM_VALIDATION", "true")

        # This is going to be ignored in lib/rubygems_plugin.rb in post_install, so I'll redefine it there
        env.define("BUNDLE_BUILD__SQLITE3", "--enable-system-libraries --with-pkg-config=pkgconf")

        env.define("PKG_CONFIG_PATH", os.path.abspath("."))
        env.vars(self, scope="build").save_script("conanbuild_gems")

        if is_msvc(self):
            vc = VCVars(self)
            vc.generate()
