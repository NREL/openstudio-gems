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
