lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trailblazer/circuit/version'

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-circuit"
  spec.version       = Trailblazer::Circuit::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = %q{BPMN-compliant workflows or state machines.}
  spec.description   = %q{BPMN-compliant workflows or state machines. Used in Trailblazer's Operation to implement the Railway.}
  spec.homepage      = "http://trailblazer.to/gems/workflow"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "raise"

  spec.required_ruby_version = '>= 2.0.0'
end
