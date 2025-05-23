require "test_helper"

class ActivityTest < Minitest::Spec
  describe "Activity#call" do
    it "accepts circuit interface" do
      flat_activity = Fixtures.flat_activity

      signal, (ctx, flow_options) = flat_activity.call([{seq: []}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)

      # b step fails.
      signal, (ctx, flow_options) = flat_activity.call([{seq: [], b: Trailblazer::Activity::Left}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b], :b=>Trailblazer::Activity::Left})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:failure>)
    end

    it "accepts {:start_task}" do
      flat_activity = Fixtures.flat_activity

      signal, (ctx, flow_options) = flat_activity.call([{seq: []}, {}], start_task: Implementing.method(:c))

      assert_equal CU.inspect(ctx), %({:seq=>[:c]})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    end

    it "accepts {:runner}" do
      flat_activity = Fixtures.flat_activity

      my_runner = ->(task, args, **circuit_options) do
        args[0][:seq] << :my_runner

        task.(args, **circuit_options)
      end

      signal, (ctx, flow_options) = flat_activity.call([{seq: []}, {}], runner: my_runner)

      assert_equal CU.inspect(ctx), %({:seq=>[:my_runner, :my_runner, :b, :my_runner, :c, :my_runner]})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    end

    it "if a signal is not connected, it throws an {IllegalSignalError} exception with helpful error message" do
      b_task          = Implementing.method(:b)
      broken_activity = Fixtures.flat_activity(wiring: {b_task => {nonsense: false, bogus: true}}) # {b} task does not connect the {Right} signal.
      class MyExecContext; end

      exception = assert_raises Trailblazer::Activity::Circuit::IllegalSignalError do
        signal, (ctx, flow_options) = broken_activity.call([{seq: []}, {}], start_task: b_task, exec_context: MyExecContext.new)
      end

      message = "ActivityTest::MyExecContext:
\e[31mUnrecognized signal `Trailblazer::Activity::Right` returned from #{b_task.inspect}. Registered signals are:\e[0m
\e[32m:nonsense
:bogus\e[0m"

      assert_equal exception.message, message

      assert_equal exception.task, b_task
      assert_equal exception.signal, Trailblazer::Activity::Right
    end

    it "automatically passes the {:activity} option" do
      # DISCUSS: in Ruby 3, procs created from the same block are identical: https://rubyreferences.github.io/rubychanges/3.0.html#proc-and-eql
      step_a = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
      step_b = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
      step_c = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }

      tasks = Fixtures.default_tasks("b" => step_b, "c" => step_c)

      flat_activity = Fixtures.flat_activity(tasks: tasks)

      tasks = Fixtures.default_tasks("b" => flat_activity, "c" => step_c)
      failure, success = flat_activity.to_h[:outputs]
      wiring = Fixtures.default_wiring(tasks, flat_activity => {failure.signal => tasks["End.failure"], success.signal => step_c} )

      nesting_activity = Fixtures.flat_activity(tasks: tasks, wiring: wiring)

      _signal, (ctx,) = nesting_activity.([[], {}])

      # each task receives the containing {:activity}
      assert_equal ctx, [flat_activity, flat_activity, nesting_activity]
    end
  end

  it "exposes {#to_h}" do
    hsh = Fixtures.flat_activity.to_h

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Activity interface.

    assert_equal hsh[:circuit].class, Trailblazer::Activity::Circuit
    assert_equal hsh[:outputs].collect{ |output| output.to_h[:semantic] }.inspect, %{[:failure, :success]}
    assert_equal hsh[:nodes].class, Trailblazer::Activity::Schema::Nodes
    assert_equal hsh[:nodes].collect { |id, attrs| attrs.id }.inspect, %{["Start.default", "b", "c", "End.failure", "End.success"]}

    assert_equal hsh[:config].inspect, "{}"
  end

  it "allows overriding {Activity.call} (this is needed in trb-pro)" do
    activity = Class.new(Trailblazer::Activity)

    call_module = Module.new do
      def call(*)
        "overridden call!"
      end
    end

    assert_equal activity.extend(call_module).call, "overridden call!"
  end
end
