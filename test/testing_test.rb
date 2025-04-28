require "test_helper"

class TestingTest < Minitest::Spec
  extend T.def_steps(:model)

  klass = Class.new do
    def self.persist
    end
  end

  class Test < Minitest::Spec
    def call
      run
      @failures
    end

    include Trailblazer::Activity::Testing::Assertions
  end

  it "what" do
    assert_equal T.render_task(TestingTest.method(:model)), %{#<Method: TestingTest.model>}
    assert_equal T.render_task(:model), %{model}
    assert_equal T.render_task(klass.method(:persist)), %{#<Method: #<Class:0x>.persist>}
  end



  it "#assert_call" do
    test = Class.new(Test) do
      let(:activity) { Fixtures.flat_activity }

    #0001
      #@ {:seq} specifies expected `ctx[:seq]`.
      it { assert_call activity, seq: "[:b, :c]" }

    #0002
      #@ allows {:terminus}
      it { assert_call activity, seq: "[:b]", terminus: :failure, b: Trailblazer::Activity::Left }

    #0003
      #@ when specifying wrong {:terminus} you get an error
      it { assert_call activity, seq: "[:b]", terminus: :not_right, b: Trailblazer::Activity::Left }

    #0004
      #@ when specifying wrong {:seq} you get an error
      it { assert_call activity, seq: "[:xxxxxx]" }

    #0005
      #@ {#assert_call} returns ctx
      it {
        ctx = assert_call activity, seq: "[:b, :c]"
        assert_equal Trailblazer::Core::Utils.inspect(ctx), %{{:seq=>[:b, :c]}}
      }

    #0006
      #@ {#assert_call} allows injecting {**ctx_variables}.
      it {
        ctx = assert_call activity, seq: "[:b, :c]", current_user: Module
        assert_equal Trailblazer::Core::Utils.inspect(ctx), %{{:seq=>[:b, :c], :current_user=>Module}}
      }
    end

    test_case = test.new(:test_0001_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0002_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0003_anonymous)
    failures = test_case.()

    assert_equal failures[0].message, %{assert_call expected not_right terminus, not #<Trailblazer::Activity::End semantic=:failure>. Use assert_call(activity, terminus: :failure).
Expected: :not_right
  Actual: :failure}

    assert_equal 1, failures.size

    test_case = test.new(:test_0004_anonymous)
    failures = test_case.()

    assert_equal failures[0].message, %{--- expected
+++ actual
@@ -1,3 +1,3 @@
 # encoding: US-ASCII
 #    valid: true
-\"#{{:seq => [:xxxxxx]}}\"
+\"#{{:seq=>[:b, :c]}}\"
}

    assert_equal 1, failures.size

    test_case = test.new(:test_0005_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0006_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0
  end

  it "{:expected_ctx_variables}" do
    test = Class.new(Test) do
      let(:activity) do
        implementing = Module.new do
          # b step adding additional ctx variables.
          def self.b((ctx, flow_options), **)
            ctx[:from_b] = 1
            return Trailblazer::Activity::Right, [ctx, flow_options]
          end
        end

        tasks = Fixtures.default_tasks("b" => implementing.method(:b))

        activity = Fixtures.flat_activity(tasks: tasks)
      end

    #0001
      #@ we can provide additional {:expected_ctx_variables}.
      it { assert_call activity, seq: "[:c]", expected_ctx_variables: {from_b: 1} }

    #0002
      #@ wrong {:expected_ctx_variables} fails
      it { assert_call activity, seq: "[:c]", expected_ctx_variables: {from_b: 2} }
    end

    test_case = test.new(:test_0001_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0002_anonymous)
    failures = test_case.()

    assert_equal failures[0].message, %{--- expected
+++ actual
@@ -1,3 +1,3 @@
 # encoding: US-ASCII
 #    valid: true
-\"#{{:seq=>[:c], :from_b=>2}}\"
+\"#{{:seq=>[:c], :from_b=>1}}\"
}
  end

  # assert_invoke
  it "#assert_invoke" do
    test = Class.new(Test) do
      class MyActivity
        def self.call((ctx, flow_options), **circuit_options)

          # ctx = ctx.merge(
          # )

          mock_ctx = MyCtx[
            **ctx,
            seq: ctx[:seq] + [:call],
            invisible: {
              flow_options: flow_options,
              circuit_options: circuit_options,
            }
          ]

          return Trailblazer::Activity::End.new(semantic: :success), [mock_ctx, flow_options]
        end
      end

      class MyCtx < Hash
        def inspect
          slice(*(keys - [:invisible])).inspect
        end

        def invisible
          self[:invisible]
        end
      end

      let(:activity) { MyActivity }

    #0001
      #@ test that we can pass {:circuit_options}
      it {
        signal, (ctx, flow_options) = assert_invoke activity, seq: "[:call]", circuit_options: {start: "yes"}

        assert_equal ctx.invisible[:circuit_options].keys.inspect, %([:start, :runner, :wrap_runtime, :activity])
        assert_equal ctx.invisible[:circuit_options][:start], "yes"
      }


    #0002
      #@ test that we can pass {:flow_options}
      it {
        signal, (ctx, flow_options) = assert_invoke activity, seq: "[:call]", flow_options: {start: "yes"}

        assert_equal ctx.invisible[:flow_options].keys.inspect, %([:start])
        assert_equal ctx.invisible[:flow_options][:start], "yes"
      }

    #0003
      #@ we return circuit interface
      it {
        signal, (ctx, flow_options) = assert_invoke activity, seq: "[:call]", flow_options: {start: "yes"}

        assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
        assert_equal Trailblazer::Core::Utils.inspect(ctx), %({:seq=>[:call]})
        assert_equal Trailblazer::Core::Utils.inspect(flow_options), %({:start=>\"yes\"})
      }

    # #0002
    #   #@ allows {:terminus}
    #   it { assert_call activity, seq: "[:b]", terminus: :failure, b: Trailblazer::Activity::Left }

    # #0003
    #   #@ when specifying wrong {:terminus} you get an error
    #   it { assert_call activity, seq: "[:b]", terminus: :not_right, b: Trailblazer::Activity::Left }

    # #0004
    #   #@ when specifying wrong {:seq} you get an error
    #   it { assert_call activity, seq: "[:xxxxxx]" }

    # #0005
    #   #@ {#assert_call} returns ctx
    #   it {
    #     ctx = assert_call activity, seq: "[:b, :c]"
    #     assert_equal Trailblazer::Core::Utils.inspect(ctx), %{{:seq=>[:b, :c]}}
    #   }

    # #0006
    #   #@ {#assert_call} allows injecting {**ctx_variables}.
    #   it {
    #     ctx = assert_call activity, seq: "[:b, :c]", current_user: Module
    #     assert_equal ctx.inspect, %{{:seq=>[:b, :c], :current_user=>Module}}
    #   }
    end

    test_case = test.new(:test_0001_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0002_anonymous)
    failures = test_case.()
    assert_equal failures.size, 0

    test_case = test.new(:test_0003_anonymous)
    failures = test_case.()
    puts failures
    assert_equal failures.size, 0
  end
end
