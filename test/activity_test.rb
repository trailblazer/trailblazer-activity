require "test_helper"

class ActivityTest < Minitest::Spec
  it "provides {#inspect}" do
    expect(Trailblazer::Activity.new({}).inspect.gsub(/0x\w+/, "0x")).must_equal %{#<Trailblazer::Activity:0x>}
  end

  it "can start with any task" do
    skip
    signal, (options,) = activity.([{}], start_task: L)

    expect(signal).must_equal activity.outputs[:success].signal
    expect(options.inspect).must_equal %{{:L=>1}}
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
    expect(bc.to_h[:nodes].values[1][:data].inspect).must_equal %{{:additional=>true}}
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
    expect(ctx).must_equal [activity, nested_activity, nested_activity, nested_activity, nested_activity, activity, activity]
  end
end
