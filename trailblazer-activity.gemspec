lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trailblazer/activity/version'

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-activity"
  spec.version       = Trailblazer::Activity::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = %q{The main element for Trailblazer's BPMN-compliant workflows.}
  spec.description   = %q{The main element for Trailblazer's BPMN-compliant workflows. Used in Trailblazer's Operation to implement the Railway.}
  spec.homepage      = "http://trailblazer.to/gems/workflow"
  spec.licenses      = ["LGPL-3.0"]

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "hirb"
  spec.add_dependency "trailblazer-context"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "trailblazer-test"

  spec.required_ruby_version = '>= 2.1.0'
end
