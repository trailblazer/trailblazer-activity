require "test_helper"

# I play a bit with the ctx vs lib_ctx idea here, first.
class TracePrototypeTest < Minitest::Spec
  Circuit = Trailblazer::Activity::Circuit
  Builder = Trailblazer::Activity::Circuit::Builder
  Task = Trailblazer::Activity::Task

  Model = Struct.new(:id)

  def capture(ctx, flow_options, signal, **kws)
    flow_options[:trace_ctx][:stack] += [CU.inspect(ctx), CU.inspect(kws)]

    return ctx, flow_options, signal
  end

  it "single LibInterface" do
    pipe = Builder.Pipeline(
      # DISCUSS: could we configure scoping to not even scope as we don't touch the {ctx}, only {flow_options}?
      [:capture_before, method(:capture), Node::Adapter::LibInterface, {}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: []], # only write to trace_ctx
    )

    pipe_node = Circuit::Node::Scoped[id: :my_model, task: pipe, interface: Circuit::Processor,
      # copy_to_outer_ctx: [:original_application_ctx]
    ]

    ctx, flow_options, signal = Trailblazer::Activity::Circuit::Node::Runner.(
      pipe_node,
      {aggregate: []}, # let's assume this is part of the local processing pipeline and from one of the recent steps.
      {
        application_ctx: {params: {id: 1}},
        trace_ctx: {stack: []},
      },
      nil,
      runner:  _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal signal, nil
    assert_equal ctx, {aggregate: []}
    assert_equal flow_options, {
      :application_ctx=>{
        :params=>{:id=>1},
      },
      :trace_ctx=>{:stack=>["{:aggregate=>[]}", "{:aggregate=>[]}"]}
    }
  end

  it "capture, task, capture" do
    # we expect the {:application_ctx} here.
    my_step_interface_exec_context = Class.new do
      def my_model_step(ctx, params:, **)
        ctx[:model] = Model.new(params[:id])
      end
    end.new

    pipe = Builder.Pipeline(
      # here, we need scoping as we're merging {:task} into {ctx}.
      [:capture_before, method(:capture), Node::Adapter::LibInterface, {task_id: "invoke_instance_method -> compute_binary_signal"}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: []], # only write to trace_ctx

      # "invoke_instance_method -> compute_binary_signal"
      [:invoke_instance_method, :my_model_step, Node::Adapter::StepInterface::InstanceMethod, {exec_context: my_step_interface_exec_context}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: [:value]],
      [:compute_binary_signal, Circuit::Step::ComputeBinarySignal, Node::Adapter::LibInterface],
    )

    pipe_node = Circuit::Node::Scoped[id: :my_model, task: pipe, interface: Circuit::Processor,
      # copy_to_outer_ctx: [:original_application_ctx]
    ]

    ctx, flow_options, signal = Trailblazer::Activity::Circuit::Node::Runner.(
      pipe_node,
      {aggregate: []}, # let's assume this is part of the local processing pipeline and from one of the recent steps.
      {
        application_ctx:  {params: {id: 1}},
        trace_ctx:        {stack: []},
      },
      nil,
      runner:  _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal signal, nil
    assert_equal ctx, {aggregate: []}
    assert_equal flow_options, {
      :application_ctx=>{:params=>{:id=>1}, model: Model.new(1)},
      :trace_ctx=>{:stack=>[flow_options = %({:aggregate=>[], :task_id=>"invoke_instance_method -> compute_binary_signal"}), flow_options]}
    }
  end

  it "what" do
skip



    my_step_interface_exec_context = Class.new do
      def my_model_step(ctx, params:, **)
        ctx[:model] = Model.new(params[:id])
      end
    end.new


    # repeating Builder::Step::InstanceMethod here:
    # here, we do not want :task from tW, and we do not want :stack around!
    model_pipe = Builder.Pipeline(
      # this step changes {application_ctx} and adds lib_ctx[:value]
      [:capture_before, method(:capture), Node::Adapter::LibInterface, {}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: []],

      # [:invoke_instance_method, :my_model_step, Node::Adapter::StepInterface::InstanceMethod, {exec_context: my_step_interface_exec_context}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: [:value]], # FIXME: implement that we reuse and "older" exec_context. for now, i ignore that for designing.

    )

    # pp model_pipe

    call_model_node = Circuit::Node::Scoped[id: :my_model, task: model_pipe, interface: Circuit::Processor,
      # copy_to_outer_ctx: [:original_application_ctx]
    ]

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Node::Runner.(
      call_model_node,
      {aggregate: []}, # let's assume this is part of the local processing pipeline and from one of the recent steps.
      {
        application_ctx: {params: {id: 1}},
        tracing_ctx: {stack: []},
      },
      nil,
      runner:  _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal ctx, {params: {id: 1}, model: Model.new(1)}
  end
end
