require "test_helper"

class ActivityTest < Minitest::Spec
  describe "Activity#call" do
    it "accepts circuit interface" do
      signal, (ctx, flow_options) = flat_activity.call([{seq: []}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)

      # b step fails.
      signal, (ctx, flow_options) = flat_activity.call([{seq: [], b: Trailblazer::Activity::Left}, {}])

      assert_equal CU.inspect(ctx), %({:seq=>[:b], :b=>Trailblazer::Activity::Left})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:failure>)
    end

    it "accepts {:start_task}" do
      signal, (ctx, flow_options) = flat_activity.call([{seq: []}, {}], start_task: Implementing.method(:c))

      assert_equal CU.inspect(ctx), %({:seq=>[:c]})
      assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    end

    it "accepts {:runner}" do
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
      broken_activity = flat_activity(wiring: {b_task => {nonsense: false, bogus: true}}) # {b} task does not connect the {Right} signal.
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
  end

  it "exposes {#to_h}" do
    hsh = flat_activity.to_h

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Activity interface.

    assert_equal hsh[:circuit].class, Trailblazer::Activity::Circuit
    assert_equal hsh[:outputs].collect{ |output| output.to_h[:semantic] }.inspect, %{[:failure, :success]}
    assert_equal hsh[:nodes].class, Trailblazer::Activity::Schema::Nodes
    assert_equal hsh[:nodes].collect { |id, attrs| attrs.id }.inspect, %{["Start.default", "b", "c", "End.failure", "End.success"]}

    assert_equal hsh[:config].inspect, "{}"
  end



  # TODO: remove remaining tests from here!

  it "{:activity}" do
    intermediate = Trailblazer::Activity::Schema::Intermediate.new(
      {
        Trailblazer::Activity::Schema::Intermediate::TaskRef(:a) => [Trailblazer::Activity::Schema::Intermediate::Out(:success, :b)],
        Trailblazer::Activity::Schema::Intermediate::TaskRef(:b) => [Trailblazer::Activity::Schema::Intermediate::Out(:success, :c)],
        Trailblazer::Activity::Schema::Intermediate::TaskRef(:c) => [Trailblazer::Activity::Schema::Intermediate::Out(:success, :d)],
        Trailblazer::Activity::Schema::Intermediate::TaskRef(:d, stop_event: true) => []
      },
      {:d => :success},
      :a # start
    )

    # DISCUSS: in Ruby 3, procs created from the same block are identical: https://rubyreferences.github.io/rubychanges/3.0.html#proc-and-eql
    step = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step2 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step3 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step4 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step5 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step6 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }
    step7 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Trailblazer::Activity::Right, [ctx, flow]] }

    implementation = {
      :a => Trailblazer::Activity::Schema::Implementation::Task(step, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :b => Trailblazer::Activity::Schema::Implementation::Task(step2, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :c => Trailblazer::Activity::Schema::Implementation::Task(step3.clone, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :d => Trailblazer::Activity::Schema::Implementation::Task(step4.clone, [], [])
    }

    nested_activity = Trailblazer::Activity.new(Trailblazer::Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

    implementation = {
      :a => Trailblazer::Activity::Schema::Implementation::Task(step5, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :b => Trailblazer::Activity::Schema::Implementation::Task(nested_activity, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :c => Trailblazer::Activity::Schema::Implementation::Task(step6, [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
      :d => Trailblazer::Activity::Schema::Implementation::Task(step7.clone, [], [])
    }

    activity = Trailblazer::Activity.new(Trailblazer::Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

    _signal, (ctx,) = activity.([[], {}])

    # each task receives the containing {:activity}
    assert_equal ctx, [activity, nested_activity, nested_activity, nested_activity, nested_activity, activity, activity]
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

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1") && RUBY_ENGINE == "ruby"
  # TODO: we can remove this once we drop Ruby <= 3.3.6.
  class GCBugTest < Minitest::Spec
    it "still finds {.method} tasks after GC compression" do
      ruby_version = Gem::Version.new(RUBY_VERSION)

      intermediate = Trailblazer::Activity::Schema::Intermediate.new(
        {
          Trailblazer::Activity::Schema::Intermediate::TaskRef(:a) => [Trailblazer::Activity::Schema::Intermediate::Out(:success, :b)],
          Trailblazer::Activity::Schema::Intermediate::TaskRef(:b, stop_event: true) => []
        },
        {:b => :success},
        :a # start
      )

      module Step
        extend T.def_tasks(:create)
      end

      implementation = {
        :a => Trailblazer::Activity::Schema::Implementation::Task(Step.method(:create), [Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)], []),
        :b => Trailblazer::Activity::Schema::Implementation::Task(Trailblazer::Trailblazer::Activity::End.new(semantic: :success), [], []),
      }

      activity = Trailblazer::Activity.new(Trailblazer::Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

      assert_invoke activity, seq: %([:create])

      if ruby_version >= Gem::Version.new("3.1") && ruby_version < Gem::Version.new("3.2")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.2.0") && ruby_version <= Gem::Version.new("3.2.6")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.3.0") #&& ruby_version <= Gem::Version.new("3.3.6")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      end

      activity = Activity.new(Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

      ruby_version_specific_options =
        if ruby_version >= Gem::Version.new("3.2") # FIXME: future
          {expand_heap: true, toward: :empty}
        else
          {}
        end

      # Provoke the bug:
      GC.verify_compaction_references(**ruby_version_specific_options)

      # Without the fix, this *might* throw the following exception:
      #
      # NoMethodError: undefined method `[]' for nil
      #     /home/nick/projects/trailblazer-activity/lib/trailblazer/activity/circuit.rb:80:in `next_for'

      assert_invoke activity, seq: %([:create])
    end
  end
end
