# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "redis/helper/version"

Gem::Specification.new do |spec|
  spec.name          = "redis-helper"
  spec.version       = Redis::Helper::VERSION
  spec.authors       = ["Narazaka"]
  spec.email         = ["info@narazaka.net"]

  spec.summary       = "helper module for models using Redis"
  spec.homepage      = "https://github.com/Narazaka/redis-helper"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    spec.metadata["yard.run"] = "yri"
  end

  spec.add_dependency "redis"
  spec.add_dependency "activesupport"
  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.5"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "onkcop"
  spec.add_development_dependency "pry"
end
