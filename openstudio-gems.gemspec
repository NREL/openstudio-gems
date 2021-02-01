
Gem::Specification.new do |spec|
  spec.name          = 'openstudio-gems'
  spec.version       = '3.1.1'
  spec.authors       = ['Nicholas Long', 'Dan Macumber', 'Katherine Fleming']
  spec.email         = ['nicholas.long@nrel.gov', 'daniel.macumber@nrel.gov', 'katherine.fleming@nrel.gov']

  spec.summary       = 'Build openstudio-gems for OpenStudio CLI and coordinate dependencies for OpenStudio Extension Gems'
  spec.description   = 'Build openstudio-gems for OpenStudio CLI and coordinate dependencies for OpenStudio Extension Gems'
  spec.homepage      = 'https://openstudio.net'

  spec.files         = []
  spec.bindir        = ''
  spec.executables   = []
  spec.require_paths = ['lib']

  # development dependencies need not be specified so strictly
  # these will not be enforced by consumers of this spec
  # bundle version is parsed by build_openstudio_gems.rb, specify all three numbers
  spec.add_development_dependency 'rake', '~> 13.0.3'
  spec.add_development_dependency 'bundler', '~> 2.1.4'

  spec.add_dependency 'rake', '13.0.3'

  spec.add_dependency 'parallel', '1.12.1'
  spec.add_dependency 'json_pure', '2.2'

  spec.add_dependency 'rspec', '3.7.0'

  spec.add_dependency 'git', '1.3.0'
  spec.add_dependency 'minitest', '5.4.3'
  spec.add_dependency 'minitest-reporters', '1.2.0'

  spec.add_dependency 'rubocop', '0.54.0'
  spec.add_dependency 'rubocop-checkstyle_formatter', '0.4'
  spec.add_dependency 'simplecov', '0.16.1'

end
