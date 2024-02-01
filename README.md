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

Using conan v2
```
conan install . --output-folder=../.deps --build=missing -s:a build_type=Release -s:a compiler.cppstd=20
. ./deps/conanbuild.sh
ruby --version
sqlite --version
```

Note: If you need to override the date that's part of the filename (defaults to today), set the env variable `DATE`

```shell
DATE=20230427 rake make_package
```


# Releasing

* Update change log
* Merge down to master
* Release via github
* run `rake release` from master
