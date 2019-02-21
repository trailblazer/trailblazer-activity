$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"

Minitest::Spec.class_eval do
  Activity  = Trailblazer::Activity
  Inter     = Trailblazer::Activity::Schema::Intermediate
  Schema    = Trailblazer::Activity::Schema

  def Cct(*args)
    Trailblazer::Developer::Render::Circuit.(*args)
      .gsub(/\d\d+/, "")
  end

  def inspect_task_builder(task)
    proc = task.instance_variable_get(:@user_proc)
    match = proc.inspect.match(/(\w+)>$/)

    %{#<TaskBuilder{.#{match[1]}}>}
  end

  Memo = Struct.new(:id, :body) do
    def self.find(id)
      return new(id, "Yo!") if id
      nil
    end
  end


  let(:implementing) do
    implementing = Module.new do
      extend T.def_tasks(:a, :b, :c, :d, :f, :g)
    end
    implementing::Start = Activity::Start.new(semantic: :default)
    implementing::Failure = Activity::End(:failure)
    implementing::Success = Activity::End(:success)

    implementing
  end

  # taskWrap tester :)
  def add_1(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end
  def add_2(wrap_ctx, original_args)
    ctx, _ = original_args[0]
    ctx[:seq] << 2
    return wrap_ctx, original_args # yay to mutable state. not.
  end

end

require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing
