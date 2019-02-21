require "test_helper"

# Test taskWrap concepts along with {Instance}s.
class TaskWrapTest < Minitest::Spec
  TaskWrap = Trailblazer::Activity::TaskWrap

  it "what" do
    intermediate = Inter.new(
      {
        Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, "End.failure")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success"), Inter::TaskRef("End.failure")],
      [Inter::TaskRef(:a)] # start
    )

    Config = Trailblazer::Activity::State::Config

    merge = [
      [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]],
    ]

    class InitializeStaticWrap
      def self.call(*)
        initial_sequence = TaskWrap::Pipeline.new([["task_wrap.call_task", TaskWrap.method(:call_task)]])
      end
    end

    a_extension_1 = TaskWrap::Extension(merge: merge, task: :a)
    a_extension_2 = ->(config:, **) { Config.set(config, :a2, :yo)   }
    b_extension_1 = ->(config:, **) { Config.set(config, :b1, false) }

    implementation = {
      :a => Schema::Implementation::Task(a = implementing.method(:a), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension.new(task: a, merge: InitializeStaticWrap),
                                                                                                                                  TaskWrap::Extension(merge: merge, task: a)]),
      :b => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output("B/success", :success)],                     [TaskWrap::Extension.new(task: b, merge: InitializeStaticWrap)]),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension.new(task: c, merge: InitializeStaticWrap)]),
      "End.success" => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }

    schema = Inter.(intermediate, implementation)

    class Acti
      def initialize(schema)
        @schema = schema
      end

      def call(*args)
        @schema[:circuit].(*args)
      end

      def [](*key)
        puts "@@@@@ #{key.inspect}"
        @schema[:config][*key]
      end
    end

    pp TaskWrap.invoke(Acti.new(schema), [{seq: []}], **{})
  end
end
