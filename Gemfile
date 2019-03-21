# gems in this file are packaged into openstudio.exe
# gems listed here should not have binary components
# gems listed here must be able to read resource files from the embedded files location
# need to adjust hard coded paths in embedded_help.rb when adding new gems
source 'http://rubygems.org'
ruby "2.2.4"

# Specify gem's dependencies in openstudio-gems.gemspec, this is what consumers of the gem will read
gemspec

# Specify specific gem source/location (e.g. github branch) for running bundle in this directory
# This is needed if the version of the gem you want to use is not on rubygems

#gem 'openstudio-extension', '= 0.0.1'
#gem 'openstudio-extension', :github => 'NREL/OpenStudio-extension-gem', :ref => '3e62211b29e28d341c4a84794f35a772c91a2145'
gem 'openstudio-extension', :github => 'NREL/OpenStudio-extension-gem', :ref => 'develop'
#gem 'openstudio-extension', :github => 'NREL/OpenStudio-extension-gem', :tag => 'v0.0.1'

gem 'openstudio-workflow', '= 1.3.3'
#gem 'openstudio-workflow', :github => 'NREL/OpenStudio-workflow-gem', :ref => '3e62211b29e28d341c4a84794f35a772c91a2145'

gem 'openstudio-standards', '= 0.2.9'
#gem 'openstudio-standards', :github => 'NREL/openstudio-standards', :ref => '77cc9971e00b603224a074bb21ce44aa61de7c3d'

gem 'simplecov', :github => 'NREL/simplecov', :ref => '98c33ffcb40fe867857a44b4d1a308f015b32e27'

gem 'openstudio_measure_tester', '= 0.1.7' # This includes the dependencies for running unit tests, coverage, and rubocop
#gem 'openstudio_measure_tester', :github => 'NREL/OpenStudio-measure-tester-gem', :ref => '273d1f1a5c739312688ea605ef4a5b6e7325332c'
