require "test_helper"

# Test injection with *scoped defaults* via taskWrap.
class DefaultsTest < Minitest::Spec
  describe "Default injection" do
    let(:macro) do
       Module.new do
        def self.model((ctx, flow_options), *)
          ctx[:model] = ctx[:model_class].new(ctx[:args])

          return Activity::Right, [ctx, flow_options]
        end
      end
    end

    def activity_for(a:, b:, a_extensions:, b_extensions:)
      intermediate = Inter.new(
        {
          Inter::TaskRef("Model_a")                       => [Inter::Out(:success, "capture_a")],
          Inter::TaskRef("capture_a")                     => [Inter::Out(:success, "Model_b")],
          Inter::TaskRef("Model_b")                       => [Inter::Out(:success, "End.success")],
          Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
        },
        ["End.success"],
        ["Model_a"], # start
      )

      capture_a = ->((ctx, flow_options), *) do
        ctx[:capture_a] = ctx.inspect
        return Activity::Right, [ctx, flow_options]
      end

      implementation = {
        "Model_a"       => Schema::Implementation::Task(a,    [Activity::Output(Activity::Right, :success)],       a_extensions),
        # :Nested         => Schema::Implementation::Task(nested, [Activity::Output(implementing::Success, :success)],                  []),
        "Model_b"       => Schema::Implementation::Task(b, [Activity::Output(Activity::Right, :success)],                        b_extensions),
        "End.success"   => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)], []),
        "capture_a"     => Schema::Implementation::Task(capture_a, [Activity::Output(Activity::Right, :success)],                  []),
      }

      schema = Inter.(intermediate, implementation)

      Activity.new(schema)
    end

    Whatever = Class.new do
      def initialize(args)
        @args = args
      end

      def inspect
        %{#<Whatever args=#{@args.inspect}>}
      end
    end

    it "provides defaults, but scopes them to the task, only. Also, you can override them by injection!" do
      a = macro.method(:model)
      b = ->(*args) { macro.model(*args) }

      activity = activity_for(a: a, b: b,
        a_extensions: [TaskWrap::Inject::Defaults::Extension(model_class: Regexp, args: "99")],
        b_extensions: [TaskWrap::Inject::Defaults::Extension(model_class: OpenStruct, args: {id: 1})],
      )

# defaults are applied
      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [{}.freeze, {}])

      signal.must_equal activity.to_h[:outputs][0].signal
      ctx.inspect.must_equal %{{:model=>#<OpenStruct id=1>, :capture_a=>\"{:model=>/99/}\"}}

# inject one value from outside, the other is still defaulted.
      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [{model_class: Whatever}.freeze, {}])

      signal.must_equal activity.to_h[:outputs][0].signal
      ctx.inspect.must_equal %{{:model_class=>DefaultsTest::Whatever, :model=>#<Whatever args={:id=>1}>, :capture_a=>\"{:model_class=>DefaultsTest::Whatever, :model=>#<Whatever args=\\\"99\\\">}\"}}
    end

    it "provides the above plus output mapping" do
      a = macro.method(:model)
      b = ->(*args) { macro.model(*args) }

      a_input  = ->((original_ctx, flow_options), *) { new_ctx = Trailblazer.Context(original_ctx) }

      a_output = ->(new_ctx, (original_ctx, flow_options), *) {
        _, mutable_data = new_ctx.decompose

        original_ctx.merge(:model_a => mutable_data[:model])
      }

      activity = activity_for(a: a, b: b,
        a_extensions: [TaskWrap::VariableMapping::Extension(a_input, a_output), TaskWrap::Inject::Defaults::Extension(model_class: Regexp, args: "99")],
        b_extensions: [TaskWrap::Inject::Defaults::Extension(model_class: OpenStruct, args: {id: 1})],
      )

# defaults are applied
      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [{}.freeze, {}])

      signal.must_equal activity.to_h[:outputs][0].signal
      ctx.inspect.must_equal %{{:model_a=>/99/, :capture_a=>\"{:model_a=>/99/}\", :model=>#<OpenStruct id=1>}}

# inject one value from outside, the other is still defaulted.
      signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [{model_class: Whatever}.freeze, {}])

      signal.must_equal activity.to_h[:outputs][0].signal
      ctx.inspect.must_equal %{{:model_class=>DefaultsTest::Whatever, :model_a=>#<Whatever args=\"99\">, :capture_a=>\"{:model_class=>DefaultsTest::Whatever, :model_a=>#<Whatever args=\\\"99\\\">}\", :model=>#<Whatever args={:id=>1}>}}
    end
  end
end
