$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"

Minitest::Spec.class_eval do
  Activity  = Trailblazer::Activity
  Inter     = Trailblazer::Activity::Schema::Intermediate
  Schema    = Trailblazer::Activity::Schema
  TaskWrap  = Trailblazer::Activity::TaskWrap

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

  let(:nested_activity) do
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B) => [Inter::Out(:success, :D)],
        Inter::TaskRef(:D) => [Inter::Out(:success, :E)],
        Inter::TaskRef(:E) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      ["Start.default"] # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  []),
      :D => Schema::Implementation::Task(c = bc, [Activity::Output(implementing::Success, :success)],                  []),
      :E => Schema::Implementation::Task(e = implementing.method(:f), [Activity::Output(Activity::Right, :success)],                  []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  let(:bc) do
     intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default")      => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B, additional: true) => [Inter::Out(:success, :C)],
        Inter::TaskRef(:C)                   => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      ["Start.default"], # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  []),
      :C => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions

end

T = Trailblazer::Activity::Testing
