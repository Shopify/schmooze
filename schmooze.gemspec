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
  spec.description   = %q{Schmooze allows a Ruby library writer to succintly interoperate between Ruby and JavaScript code. It has a clever DSL to make this possible.}
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.homepage      = 'https://github.com/Shopify/schmooze'

  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
