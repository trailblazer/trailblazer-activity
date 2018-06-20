source "https://rubygems.org"

# Specify your gem's dependencies in workflow.gemspec
gemspec

gem "benchmark-ips"
gem "minitest-line"

gem "rubocop", require: false

case ENV["GEMS_SOURCE"]
  when "local"
    gem "trailblazer-context", path: "../trailblazer-context"
    gem "trailblazer-test", path: "../trailblazer-test"
  when "github"
    gem "trailblazer-context", git: "https://github.com/trailblazer/trailblazer-context"
    gem "trailblazer-test", git: "https://github.com/trailblazer/trailblazer-test"
  when "custom"
    eval_gemfile("GemfileCustom")
  else # use rubygems releases
    gem "trailblazer-context"
    gem "trailblazer-test", git: "https://github.com/trailblazer/trailblazer-test"
end
