require "test_helper"

# Test taskWrap concepts along with {Instance}s.
class TaskWrapTest < Minitest::Spec
  TaskWrap  = Trailblazer::Activity::TaskWrap
  Config    = Trailblazer::Activity::State::Config

  it "what" do
    intermediate = Inter.new(
      {
        Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success")],
      [Inter::TaskRef(:a)] # start
    )

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
      :b => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension.new(task: b, merge: InitializeStaticWrap)]),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension.new(task: c, merge: InitializeStaticWrap)]),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], [TaskWrap::Extension.new(task: es, merge: InitializeStaticWrap)]), # DISCUSS: End has one Output, signal is itself?
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
        @schema[:config][*key]
      end
    end

    signal, (ctx, flow_options) = TaskWrap.invoke(Acti.new(schema), [{seq: []}], **{})

    ctx.inspect.must_equal %{{:seq=>[1, :a, 2, :b, :c]}}
  end
end
