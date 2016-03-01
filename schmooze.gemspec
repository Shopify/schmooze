# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'schmooze/version'

Gem::Specification.new do |spec|
  spec.name          = 'schmooze'
  spec.version       = Schmooze::VERSION
  spec.authors       = ['Bouke van der Bijl']
  spec.email         = ['bouke@shopify.com']

  spec.license       = "MIT"
  spec.summary       = %q{Schmooze lets Ruby and Node.js work together intimately.}
  spec.description   = File.read(File.join(__dir__, 'README.md'))
  spec.homepage      = 'https://github.com/Shopify/schmooze'

  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
