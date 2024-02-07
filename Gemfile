# gems in this file are packaged into openstudio.exe
# gems listed here should not have binary components
# gems listed here must be able to read resource files from the embedded files location
# need to adjust hard coded paths in embedded_help.rb when adding new gems
source 'http://rubygems.org'
# ruby "~> 3.2.2"

# Specify gem's dependencies in openstudio-gems.gemspec, this is what consumers of the gem will read
gemspec

# Specify specific gem source/location (e.g. github branch) for running bundle in this directory
# This is needed if the version of the gem you want to use is not on rubygems

LOCAL_DEV = false
MINIMAL_GEMS = true    # Keep only one non-native gem, and one native

if !MINIMAL_GEMS
  # Bug in addressable to 2.8.1 and patched version has an issue https://github.com/NREL/OpenStudio/issues/4870
  gem 'addressable', '= 2.8.1'
  gem 'openstudio-standards', '= 0.5.0'
  gem 'json_schemer', '= 2.0.0'
end

if LOCAL_DEV

  gem 'oslg', path: '../oslg'
  if !MINIMAL_GEMS
    gem 'tbd', path: '../tbd'
    gem 'osut', path: '../osut'
    gem 'openstudio-extension', '= 0.7.1', path: '../openstudio-extension-gem'
    gem 'openstudio-workflow', '= 2.3.1', path: '../OpenStudio-workflow-gem'
    gem 'openstudio_measure_tester', '= 0.3.3', path: "../OpenStudio-measure-tester-gem"
    gem 'bcl', path: '../bcl-gem'
  end

  group :native_ext do
    gem 'jaro_winkler',  path: '../ext/jaro_winkler'
    if !MINIMAL_GEMS
      gem 'pycall', path: '../ext/pycall.rb'
      gem 'sqlite3', path: '../ext/sqlite3-ruby'
      # You need ragel available (version 6.x, eg `ragel_installer/6.10@bincrafters/stable` from conan)
      gem 'oga', '3.2'
      # gem 'cbor', '0.5.9.6' # Cbor will require a ton of patching, so disabling it in favor of msgpack (cbor is a fork of msgpack anyways)
      gem 'msgpack', '1.7.2'
    end
  end

else

  gem 'oslg', :github => 'jmarrec/oslg', :ref => 'ruby3'

  if !MINIMAL_GEMS
    gem 'tbd', :github => 'jmarrec/tbd', :ref => 'ruby3'
    gem 'osut', :github => 'jmarrec/osut', :ref => 'ruby3'

    gem 'openstudio-extension', '= 0.7.1',:github => 'NREL/openstudio-extension-gem', :ref => 'ruby3'
    gem 'openstudio-workflow', '= 2.3.1', :github => 'NREL/OpenStudio-workflow-gem', :ref => 'ruby3'
    gem 'openstudio_measure_tester', '= 0.3.3', :github => 'NREL/OpenStudio-measure-tester-gem', :ref => 'ruby3'
    gem 'bcl', "= 0.8.0", :github => 'jmarrec/bcl-gem', :ref => 'ruby3'
  end

  group :native_ext do
    gem 'jaro_winkler', '= 1.5.6', :github => 'jmarrec/jaro_winkler', :ref => 'msvc-ruby3'

    if !MINIMAL_GEMS
      gem 'pycall', '= 1.5.1', :github => 'jmarrec/pycall.rb', :ref => 'update-finder-v1.5.1'
      # gem 'sqlite3', :github => 'jmarrec/sqlite3-ruby', :ref => 'MSVC_support'
      # gem 'sqlite3', :github => 'sparklemotion/sqlite3-ruby', :ref => "v1.7.2"
      gem 'sqlite3', '= 1.7.2'

      # You need ragel available (version 6.x, eg `ragel_installer/6.10@bincrafters/stable` from conan)
      gem 'oga', '3.2'
      # gem 'cbor', '0.5.9.6' # Cbor will require a ton of patching, so disabling it in favor of msgpack (cbor is a fork of msgpack anyways)
      gem 'msgpack', '1.4.2'
    end
  end
end

# leave this line in for now as we may try to get nokogiri to compile correctly on windows
# gem 'nokogiri', '= 1.11.0.rc1.20200331222433', :github => 'jmarrec/nokogiri', :ref => 'MSVC_support' # master of 2020-03-31 + gemspec commit
