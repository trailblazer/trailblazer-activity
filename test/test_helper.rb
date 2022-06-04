require "pp"
require "trailblazer-activity"
require "trailblazer/developer/render/circuit"

require "minitest/autorun"

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

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

  # taskWrap tester :)
  def add_1(wrap_ctx, original_args)
    ctx, = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  def add_2(wrap_ctx, original_args)
    ctx, = original_args[0]
    ctx[:seq] << 2
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions
end

T = Trailblazer::Activity::Testing
