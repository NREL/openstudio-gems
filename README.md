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

To build openstudio-gems package for OpenStudio CLI call `rake make_package`.

# Releasing

* Update change log
* Merge down to master
* Release via github
* run `rake release` from master