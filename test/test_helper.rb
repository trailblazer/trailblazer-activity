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

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions
end

T = Trailblazer::Activity::Testing
