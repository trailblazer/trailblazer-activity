require "benchmark/ips"
require "trailblazer/activity"

=begin
## Learning

=end

module Form
  extend Trailblazer::Activity::Path()

  module_function

  def parse(ctx, model:, **)
    model[:email] = "yo@trb.to"
  end

  task method(:parse)
end

module Create
  extend Trailblazer::Activity::Path()

  module_function

  def model(ctx, **)
    ctx[:model] = {}
  end

  def save(ctx, model:, **)
    model[:save] = true
  end

  task method(:model)
  task Subprocess(Form)
  task method(:save)
end

def run
  signal, (ctx, _) = Create.({})
  # pp ctx
end

Benchmark.ips do |x|
  x.report("@") { run }

  x.compare!
end
