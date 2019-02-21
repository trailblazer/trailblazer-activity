$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"

Minitest::Spec.class_eval do
  Activity = Trailblazer::Activity

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
end

require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing
