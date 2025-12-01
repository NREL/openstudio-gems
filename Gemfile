# gems in this file are packaged into openstudio.exe
# gems listed here should not have binary components
# gems listed here must be able to read resource files from the embedded files location
# need to adjust hard coded paths in embedded_help.rb when adding new gems
source 'http://rubygems.org'
ruby '~> 3.2.2'

# Specify gem's dependencies in openstudio-gems.gemspec, this is what consumers of the gem will read
gemspec

# Specify specific gem source/location (e.g. github branch) for running bundle in this directory
# This is needed if the version of the gem you want to use is not on rubygems

LOCAL_DEV = false
MINIMAL_GEMS = false # Keep only one non-native gem, and one native
FINAL_PACKAGE = !ENV['FINAL_PACKAGE'].nil?

unless MINIMAL_GEMS
  # Bug in addressable to 2.8.1 and patched version has an issue https://github.com/NREL/OpenStudio/issues/4870
  gem 'addressable', '= 2.8.8'
  # gem 'json_schemer', '= 2.0.0' # Disabled, see #72 and https://github.com/NREL/OpenStudio/issues/4969#issuecomment-1943418472
end

unless MINIMAL_GEMS
  # 2.9.1 changed a bunch of require with require_relative and that's
  # apparently causing problems
  # gem 'regexp_parser', '2.11.2'
end

if LOCAL_DEV

  gem 'oslg', path: '../oslg'
  unless MINIMAL_GEMS
    gem 'bcl', path: '../bcl-gem'
    gem 'openstudio-extension', '= 0.9.5', path: '../openstudio-extension-gem'
    gem 'openstudio_measure_tester', '= 0.5.1', path: '../OpenStudio-measure-tester-gem'
    gem 'openstudio-standards', '= 0.8.4', path: '../openstudio-standards'
    gem 'openstudio-workflow', '= 2.5.0', path: '../OpenStudio-workflow-gem'
    gem 'osut', path: '../osut'
    gem 'tbd', path: '../tbd'

    # This removes the runtime dependency on 'json ~> 2.3'. Our CLI, via ruby
    # itself already has json 2.6.2 which is good enough
    gem 'rubocop', '= 1.81.7'
  end

  group :native_ext do
    gem 'jaro_winkler', '= 1.6.1'
    gem 'json', '~> 2.6.3'
    unless MINIMAL_GEMS
      gem 'sqlite3', '= 2.8.1'
      # You need ragel available (version 6.x, eg `ragel_installer/6.10@bincrafters/stable` from conan)
      # 'oga' was chosen as the parser because 'nokogiri' is not supported on windows
      gem 'oga', '3.4'
      # gem 'cbor', '0.5.9.6' # Cbor will require a ton of patching, so disabling it in favor of msgpack (cbor is a fork of msgpack anyways)
      gem 'msgpack', '1.7.2'
    end
  end

elsif !FINAL_PACKAGE

  gem 'oslg', '= 0.4.0'

  unless MINIMAL_GEMS
    gem 'osut', '= 0.8.0'
    gem 'tbd', '~> 3.5.0'

    # gem 'openstudio-standards', '= 0.8.2.rc1', :github => 'NREL/openstudio-standards', :ref => 'v0.8.2.rc1'
    # gem 'openstudio-extension', '= 0.8.0',:github => 'NREL/openstudio-extension-gem', :ref => '2e86077dce1688443cca462feda3239ef47c232c'
    # gem 'openstudio-workflow', '= 2.5.0', :github => 'NREL/OpenStudio-workflow-gem', :ref => '32126e9b9f6bd6ed1ee55331f6dadbb3ba1e7cd2'
    # gem 'openstudio_measure_tester', '= 0.4.0', :github => 'NREL/OpenStudio-measure-tester-gem', :ref => '89b9b7eb5f2d2ef91e225585a09e076577f25d4a'
    # gem 'bcl', "= 0.8.0", :github => 'NREL/bcl-gem', :ref => '3c60cadc781410819e7c9bfb8d7ba1af146d9abd'
    gem 'bcl', '= 0.9.1'
    gem 'openstudio-extension', '= 0.9.5'
    gem 'openstudio_measure_tester', '= 0.5.1'
    gem 'openstudio-standards', '= 0.8.4'
    gem 'openstudio-workflow', '= 2.5.0'

    gem 'rubocop', '= 1.81.7'
  end

  group :native_ext do
    gem 'jaro_winkler', '= 1.6.1'
    gem 'json', '~> 2.6.3'

    unless MINIMAL_GEMS
      # gem 'sqlite3', :github => 'jmarrec/sqlite3-ruby', :ref => 'MSVC_support'
      # gem 'sqlite3', :github => 'sparklemotion/sqlite3-ruby', :ref => "v1.7.2"
      gem 'sqlite3', '= 2.8.1'

      # You need ragel available (version 6.x, eg `ragel_installer/6.10@bincrafters/stable` from conan)
      # 'oga' was chosen as the parser because 'nokogiri' is not supported on windows
      gem 'oga', '3.4'
      # gem 'cbor', '0.5.9.6' # Cbor will require a ton of patching, so disabling it in favor of msgpack (cbor is a fork of msgpack anyways)
      gem 'msgpack', '1.7.2'
    end
  end
else

  puts 'FINAL_PACKAGE'

  gem 'oslg', '= 0.4.0'

  unless MINIMAL_GEMS
    gem 'osut', '= 0.8.0'
    gem 'tbd', '= 3.5.0'

    gem 'bcl', '= 0.9.1'
    gem 'openstudio-extension', '= 0.9.5'
    gem 'openstudio_measure_tester', '= 0.5.1'
    gem 'openstudio-standards', '= 0.8.4'
    gem 'openstudio-workflow', '= 2.5.0'

    gem 'rubocop', '= 1.81.7'
  end

  group :native_ext do
    gem 'jaro_winkler', '= 1.6.1'
    gem 'json', '~> 2.6.3'

    unless MINIMAL_GEMS
      # gem 'sqlite3'
      # gem 'sqlite3'
      gem 'sqlite3', '= 2.8.1'

      # You need ragel available (version 6.x, eg `ragel_installer/6.10@bincrafters/stable` from conan)
      # 'oga' was chosen as the parser because 'nokogiri' is not supported on windows
      gem 'oga', '3.4'
      # gem 'cbor', '0.5.9.6' # Cbor will require a ton of patching, so disabling it in favor of msgpack (cbor is a fork of msgpack anyways)
      gem 'msgpack', '1.7.2'
    end
  end

end

gem 'byebug', '~> 12.0.0'
gem 'webrick', '~> 1.9.2'
