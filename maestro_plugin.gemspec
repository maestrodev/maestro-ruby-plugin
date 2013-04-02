# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'maestro_plugin/version'

Gem::Specification.new do |spec|
  spec.name          = 'maestro_plugin'
  spec.version       = Maestro::Plugin::VERSION
  spec.authors       = ['Etienne Pelletier']
  spec.email         = ['epelletier@maestrodev.com']
  spec.description   = %q{A ruby library to help with the creation of Maestro plugins}
  spec.summary       = %q{Maestro ruby plugin}
  spec.homepage      = 'https://github.com/maestrodev/maestro-ruby-plugin'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'logging', '1.8.0'
  spec.add_dependency 'rubyzip', '0.9.8'
  spec.add_dependency 'json', '>= 1.4.6'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'gemfury', '~> 0.4.9'
  spec.add_development_dependency 'jruby-openssl'

  spec.add_development_dependency 'rspec', '2.7.0'


end
