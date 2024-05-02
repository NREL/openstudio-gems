# OpenStudio Gems

Repository to store Gemfiles used when building OpenStudio. This repository can be used to coordinate Gemfile dependencies when using multiple OpenStudio Extension Gems.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-gems'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-gems'

## Usage

To build openstudio-gems package for OpenStudio CLI call `rake make_package`, but before make sure you are:

1. Using the right ruby version
2. You have the conan dependencies in your PATH

### Using conan v2
```
conan install . --output-folder=../os-gems-deps --build=missing -s:a build_type=Release -s:a compiler.cppstd=20 -o '*/*:shared=False'
. ../os-gems-deps/conanbuild.sh
ruby --version
sqlite3 --version
echo $PKG_CONFIG_PATH
gem install rake
rake make_package
```

### On Windows with Powershell

You probably should checkout the repo at a very short path to begin with, and you will likely need to enable git support for long paths if not, and enable the LONG PATHS feature of windows

Powershell, as admin:

```shell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force`
git config --system core.longpaths true
```

```shell
conan install . --output-folder=../os-gems-deps --build=missing -s:a build_type=Release -s:a compiler.cppstd=20 -o '*/*:shared=False' -c tools.env.virtualenv:powershell=True
& ..\os-gems-deps\conanbuild.ps1
ruby --version
sqlite3 --version
echo $env:PKG_CONFIG_PATH
gem install rake
rake make_package
```

### Adjusting the date

Note: If you need to override the date that's part of the filename (defaults to today), set the env variable `DATE`

```shell
DATE=20230427 rake make_package
```


# Releasing

* Update change log
* Merge down to master
* Release via github
* run `rake release` from master

# Recommandations for gem owners

* Gem owners are encouraged to start releasing pre/rc packages on rubygems. It would avoid several issues
    * Downloading from git is slow for large repositories
    * It also avoids the issues where they could go into the .bundle/ruby/bundler folder and not .bundle/ruby/gems one (which we worked-around for openstudio-gems by repacking them manually...)

## Need a native gem as a dependency and intend to use the CLI with --bundle

Using a native gem as a dependency can cause conflicts in the CLI. This is because the CLI is statically built, but `bundle install` with your system ruby will build a shared extension.
We have mostly worked-around this issue by ensuring that any native dependency in the Gemfile.lock that is satisfied by an embedded CLI native gem will be picked up.

But this is fragile and prone to problems.

Anything that is, or indirectly pulls, a native dependency that is already bundled with our CLI should be put in the `:test` group in the Gemfile (or added via `spec.add_development_dependency` which is the same result from the gempsec file). This is because by default `--bundle_without` is `[test]`.

Or in a `:native` group, and you call the CLI with `--bundle_without "test native"`.

That way we don't even run into such issues, the CLI version is used and that's it.

If you definitely need a native gem that is NOT part of the CLI already, then either:

* It should be part of the CLI anyways if you intend to use the CLI to run your thing... So request it, and we'll see if we can compile it statically (for MSVC especially)
* Otherwise don't try to use the CLI with `--bundle` (via for eg `rake openstudio:test_with_openstudiowhich` uses a CLI call with `--bundle` underneath). 
        * You **can** use the `openstudio-measure-tester-gem` directly without the `openstudio-extension-gem` and stay in ruby... Or use `Rake::TestTask` or a modified version of that directly.
