require "test_helper"

class ActivityTest < Minitest::Spec
  it "provides {#inspect}" do
    assert_equal Trailblazer::Activity.new({}).inspect.gsub(/0x\w+/, "0x"), %{#<Trailblazer::Activity:0x>}
  end

  it "can start with any task" do
    skip
    signal, (options,) = activity.([{}], start_task: L)

    assert_equal signal, activity.outputs[:success].signal
    assert_equal options.inspect, %{{:L=>1}}
  end

  it "exposes {#to_h}" do
    hsh = flat_activity.to_h

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Activity interface.

    assert_equal hsh[:circuit].class, Trailblazer::Activity::Circuit
    assert_equal hsh[:outputs].collect{ |output| output.to_h[:semantic] }.inspect, %{[:success, :failure]}
    assert_equal hsh[:nodes].class, Trailblazer::Activity::Schema::Nodes
    assert_equal hsh[:nodes].collect { |id, attrs| attrs.id }.inspect, %{["Start.default", :B, :C, "End.success", "End.failure"]}
    assert_equal hsh[:config].inspect, "{:wrap_static=>{}}"
  end

  # TODO: test {to_h} properly
  it "exposes {:data} attributes in {#to_h}" do
    assert_equal bc.to_h[:nodes].values[1][:data].inspect, %{{:additional=>true}}
  end

  it "{:activity}" do
    intermediate = Activity::Schema::Intermediate.new(
      {
        Activity::Schema::Intermediate::TaskRef(:a) => [Activity::Schema::Intermediate::Out(:success, :b)],
        Activity::Schema::Intermediate::TaskRef(:b) => [Activity::Schema::Intermediate::Out(:success, :c)],
        Activity::Schema::Intermediate::TaskRef(:c) => [Activity::Schema::Intermediate::Out(:success, :d)],
        Activity::Schema::Intermediate::TaskRef(:d, stop_event: true) => []
      },
      {:d => :success},
      :a # start
    )

    # DISCUSS: in Ruby 3, procs created from the same block are identical: https://rubyreferences.github.io/rubychanges/3.0.html#proc-and-eql
    step = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step2 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step3 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step4 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step5 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step6 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }
    step7 = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }

    implementation = {
      :a => Schema::Implementation::Task(step, [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(step2, [Activity::Output(Activity::Right, :success)], []),
      :c => Schema::Implementation::Task(step3.clone, [Activity::Output(Activity::Right, :success)], []),
      :d => Schema::Implementation::Task(step4.clone, [], [])
    }

    nested_activity = Activity.new(Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

    implementation = {
      :a => Schema::Implementation::Task(step5, [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(nested_activity, [Activity::Output(Activity::Right, :success)], []),
      :c => Schema::Implementation::Task(step6, [Activity::Output(Activity::Right, :success)], []),
      :d => Schema::Implementation::Task(step7.clone, [], [])
    }

    activity = Activity.new(Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

    _signal, (ctx,) = activity.([[], {}])

    # each task receives the containing {:activity}
    assert_equal ctx, [activity, nested_activity, nested_activity, nested_activity, nested_activity, activity, activity]
  end

  it "allows overriding {Activity.call} (this is needed in trb-pro)" do
    activity = Class.new(Activity)

    call_module = Module.new do
      def call(*)
        "overridden call!"
      end
    end

    assert_equal activity.extend(call_module).call, "overridden call!"
  end
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1")
  # TODO: we can remove this once we drop Ruby <= 3.3.6.
  class GCBugTest < Minitest::Spec
    it "still finds {.method} tasks after GC compression" do
      ruby_version = Gem::Version.new(RUBY_VERSION)

      intermediate = Activity::Schema::Intermediate.new(
        {
          Activity::Schema::Intermediate::TaskRef(:a) => [Activity::Schema::Intermediate::Out(:success, :b)],
          Activity::Schema::Intermediate::TaskRef(:b, stop_event: true) => []
        },
        {:b => :success},
        :a # start
      )

      module Step
        extend T.def_tasks(:create)
      end

      implementation = {
        :a => Schema::Implementation::Task(Step.method(:create), [Activity::Output(Activity::Right, :success)], []),
        :b => Schema::Implementation::Task(Trailblazer::Activity::End.new(semantic: :success), [], []),
      }

      activity = Activity.new(Activity::Schema::Intermediate::Compiler.(intermediate, implementation))

      assert_invoke activity, seq: %([:create])

      if ruby_version >= Gem::Version.new("3.1") && ruby_version < Gem::Version.new("3.2")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.2.0") && ruby_version <= Gem::Version.new("3.2.6")
        require "trailblazer/activity/circuit/ruby_with_unfixed_compaction"
        Trailblazer::Activity::Circuit.prepend(Trailblazer::Activity::Circuit::RubyWithUnfixedCompaction)
      elsif ruby_version >= Gem::Version.new("3.3.0") && ruby_version <= Gem::Version.new("3.3.6")
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
