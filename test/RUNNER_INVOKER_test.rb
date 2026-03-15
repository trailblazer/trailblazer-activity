require "test_helper"



# TODO:
# 1. SOMETHINg like Pipe::Input, nested pipe, check out how to use a work ctx
# [2. done] do we need pipelines?
# 3. runtime tw
# 4. show how task can be replaced at runtime, e.g. for Nested
# 5. how to call with kwargs, e.g. in Rescue?
# 6. "scopes" for tracing? E.g. "only trace business steps"
# 7. try saving memory by providing often-used Pipes, e.g. for IO?
# 8. how would we change the "circuit options" from a step? ===> change :start_task
# 9. does invoker.call need kwargs?
# [10. done] BUG: when all tasks are the same proc and the last is the terminus, only the first is run. ===> use ids, we got them, anyway.
# 11. should circuit_options be a positional arg?
# [12. done] don't repeat io.new as context, use automatic passing [done]
# 13. termini IDs in map when using nesting

class RunnerInvokerTest < Minitest::Spec
  it "circuit_options, depth-only" do
    def capture_task(id:)
      ->(ctx, lib_ctx, circuit_options, **) do
        ctx[:captured] << [id, circuit_options[:exec_context], circuit_options[:lib_exec_context]].compact
        return ctx, lib_ctx, nil
      end
    end

    model_pipe = lib_pipeline(
      [:input, capture_task(id: 1), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface],
      [:model, capture_task(id: 2), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface],
      [:output, capture_task(id: 3), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface],
    )

    validate_input_pipe = lib_pipeline(
      [:input, capture_task(id: 4), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface],
      [:exec_on__parent, capture_task(id: 5), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface], # exec on original ctx!
    )

    validate_pipe = lib_pipeline(
      [:Validate_input, validate_input_pipe, Trailblazer::Activity::Circuit::Processor, {lib_exec_context: "Validate::Input"}],
      [:validate, capture_task(id: 6), Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface],
    )

    create_pipe = lib_pipeline(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    # As we pass in exec_context: as a kwarg, it's passed to all siblings etc.
    ctx, _ = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: []}, {}, {exec_context: "Object"}, nil)
    assert_equal ctx[:captured], [[1, "Object"], [2, "Object"], [3, "Object"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]

# FIXME: new test case.
puts
    create_pipe = lib_pipeline(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: "Model"}],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    ctx, _ = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: []}, {}, {exec_context: "Object"}, nil)
    assert_equal ctx[:captured], [[1, "Model"], [2, "Model"], [3, "Model"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]
  end

  def lib_pipeline(*args, **kws)
    Trailblazer::Activity::Circuit::Builder.Pipeline(*args, **kws)
  end

  it "Signal Pipeline / signal scoping" do
    skip
    my_tw = Class.new do
      def self.a(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :a

        return ctx, lib_ctx, signal
      end

      def self.b(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :b

        return ctx, lib_ctx, signal
      end

      def self.c(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :c

        return ctx, lib_ctx, signal
      end

      def self.d(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :d

        return ctx, lib_ctx, signal
      end

      def self.my_signal_step(ctx, lib_ctx, circuit_options)
        return ctx, lib_ctx.merge(seq: lib_ctx[:seq] + [:my_signal_step]), Trailblazer::Activity::Right # returning Right here "breaks" the "next task resolving" in an unconfigured world.
      end

      def self.my_left_signal_step(ctx, lib_ctx, circuit_options)
        seq = lib_ctx[:seq] + [:my_left_signal_step]

        return ctx, lib_ctx.merge(seq: seq), Trailblazer::Activity::Left # FIXME: merge doesn't work!
      end
    end

    invoke_instance_method_lib_circuit = lib_pipeline(
      [:d, :d, ],
      [:my_left_signal_step, :my_left_signal_step, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface::InstanceMethod],
      exec_context: my_tw
    )

  # Out => [:seq], Out() => <signal>
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(invoke_instance_method_lib_circuit, {}, {seq: []}, {copy_to_outer_ctx: [:seq]}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:d, :my_left_signal_step]})
    assert_equal signal, Trailblazer::Activity::Left # signal from {my_left_signal_step}.

  # Out => [:seq], discard inner <signal>
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(invoke_instance_method_lib_circuit, {}, {seq: []}, {copy_to_outer_ctx: [:seq], return_outer_signal: true}, Object)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:d, :my_left_signal_step]})
    assert_equal signal, Object # signal from {my_left_signal_step} got discarded.



  # Nesting
    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c]})
    assert_equal signal, Trailblazer::Activity::Left

  # Nesting with two signal producers on the same branch/level.
  # the second wins with Right.
    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
      [:output, :my_signal_step, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface::InstanceMethod], # this signal wins, because it's not configured!
      [:d, :d],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c, :my_signal_step, :d]})
    assert_equal signal, Trailblazer::Activity::Right


  # Nesting with two signal producers on the same branch/level.
  # the second's Right signal gets discarded.
    output_pipe = lib_pipeline(
      [:emit_right, :my_signal_step, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface::InstanceMethod],
    )

    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
      [:output, output_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq], return_outer_signal: true}],
      [:d, :d],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c, :my_signal_step, :d]})
    assert_equal signal, Trailblazer::Activity::Left


    raise


    signal_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],



      [:my_signal_step, :my_signal_step, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface::InstanceMethod],
      [:c, :c],
      exec_context: my_tw
    )



    library_pipeline = MyLibraryPipeline.new(**signal_pipe.to_h)

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(library_pipeline, {}, {seq: []}, {}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b]})
    assert_equal signal, Trailblazer::Activity::Right
  end

  require "ruby-prof"
  it "ruby-prof" do
    create_circuit, create_termini, model_input_pipe, model_output_pipe = Fixtures.fixtures()
    # profile the code
    result = RubyProf::Profile.profile do
      puts call_me(create_circuit)
    end

    # print a graph profile to text
    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT)
  end


require "benchmark/ips"
  it do
    create_circuit, create_outputs, model_input_pipe, model_output_pipe = Fixtures.fixtures()

    # context_implementation = Trailblazer::Context
    context_implementation = Trailblazer::MyContext
    # context_implementation = Trailblazer::MyContext_No_Slice


# pp model_input_pipe
# TEST I/O

#  Benchmark.ips do |x|
#    x.report("cix") {
  lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Processor.(model_input_pipe,
    {exec_context:  IO___.new},
    {application_ctx: {params: {song: {}}, noise: true, slug: "0x666"}},
    nil,
    # copy_to_outer_ctx: [:original_application_ctx],
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )

  lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Node::Runner.(
    Trailblazer::Activity::Circuit::Node::Scoped[id: :my_model, task: model_input_pipe, interface: Trailblazer::Activity::Circuit::Processor, copy_to_outer_ctx: [:original_application_ctx]],
    {exec_context:  IO___.new},
    {application_ctx: {params: {song: {}}, noise: true, slug: "0x666"}},
    nil,
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )
 # }
 #   x.compare! # 43.6 -45.2k
 # end

   # Context():
   #   1.) 25.4k
   #   2.) 36.7k (simple Context)

  # raise ctx.inspect
  ctx = flow_options[:application_ctx]
  assert_equal ctx.class, Trailblazer::Context # our In pipe's creation!
  assert_equal ctx[:more], "0x666" # the more_model_input was called.
  assert_equal lib_ctx[:original_application_ctx].class, Hash # the OG ctx is a Hash.
  assert_equal lib_ctx.keys, [:exec_context, :original_application_ctx]
  assert_equal CU.inspect(ctx), %(#<struct Trailblazer::Context shadowed={:params=>{:song=>{}, :slug=>\"0x666\"}, :more=>\"0x666\"}, mutable={}>)

  # this is what happens in the actual {:model} step.
  ctx[:model] = Object

  # lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_output_pipe,
  #   ctx,
  #   lib_ctx,
  #   {copy_to_outer_ctx: [],
  #       exec_context: IO___.new,},
  #   nil
  # )
  ctx = ctx.to_h
  puts :yoo

  lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Node::Runner.(
    Trailblazer::Activity::Circuit::Node::Scoped[id: :my_model, task: model_output_pipe, interface: Trailblazer::Activity::Circuit::Processor],
    lib_ctx,
    {application_ctx: ctx},
    nil,
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )
# FIXME!!!!!!!!!!!!!!!!!!!!!! original_application_ctx shooouldn't contain {model}?
  assert_equal flow_options[:application_ctx].inspect, %({:params=>{:song=>{}}, :noise=>true, :slug=>"0x666", :model=>Object})















  flow_options = {application_ctx: {params: {song: nil}, slug: "0x666"}}
  # create_ctx = {
  #   # exec_context:     Create.new,
  #   application_ctx:  ctx
  # }

puts "ciiii"
  # validation error:
  lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, {}, flow_options, nil, runner: _A::Circuit::Node::Runner, context_implementation: context_implementation,) # FIXME: use process_node/canonical invoke?

  assert_equal flow_options[:application_ctx], {:params=>{:song=>nil}, slug: "0x666", :model=>"Object  / {:more=>\"0x666\"}", :errors=>["Object  / {:more=>\"0x666\"}", :song]}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_outputs[:failure]

puts "ywiiii"
  # success:
  lib_ctx, flow_options, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, {}.freeze, {application_ctx: {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}}, nil,
    runner: _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )

  assert_equal flow_options[:application_ctx], {:params=>{:song=>{title: "Uwe"}, id: 1}, slug: "0x666", :model=>"Object 1 / {:more=>\"0x666\"}", :save=>"Object 1 / {:more=>\"0x666\"}"}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_outputs[:success]
end

  it "run benchmark" do
    create_circuit, = Fixtures.fixtures()

    Benchmark.ips do |x|
      x.report("simple hash Context") {
        ctx, signal = call_me_with_simpler_context(create_circuit)
      }
      x.compare!
    end
  end

  it "run benchmark for different {:context_implementation}" do
    create_circuit, = Fixtures.fixtures()

    Benchmark.ips do |x|
      x.report("cix") {
        ctx, signal = call_me(create_circuit)
      }
      x.report("hash Contextt") {
        ctx, signal = call_me_with_simpler_context(create_circuit)
      }
      x.report("hash Contextt no slice") {
        ctx, signal = call_me_with_simpler_context_and_no_slice(create_circuit)
      }
      x.compare!
    end
  end

  def call_me(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::Context,
    )
  end

  def call_me_with_simpler_context(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )
  end

  def call_me_with_simpler_context_and_no_slice(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext_No_Slice,
    )
  end
  # 1.
  #   5.648k vs 19.834k how is that so slow?
  # 2. circuit map now is based on ID symbols and not [id, task, invoker, ...] which was obviously very slow to compute the key every time
  #   21.847k that is a lot faster!

  # save_pipe = [
  #   a = [:input, Model___Input, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface, {}],

  #   b= [:invoke_callable, Save, Trailblazer::Activity::Circuit::Task::Adapter::StepInterface, {}],
  #   c= [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface, {}],

  #   d =[:output, Model___Output, Trailblazer::Activity::Circuit::Task::Adapter::CircuitInterface, {}],
  # ]


  # save_circuit = {
  #   a => {nil => b},
  #   b => {nil => c},
  #   c => {Trailblazer::Activity::Right => d},
  #   # d => {Trailblazer::Activity::Right => create_success_terminus},
  # }

  # save_circuit = Circuit.new(map: save_circuit, termini: [Model___Output], start_task_id: a)

  # ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(save_circuit, {application_ctx: {params: {}, model: Object}})
  # ctx, signal = Pipeline::Processor.(save_pipe, {application_ctx: {params: {}, model: Object}})
  # raise ctx.inspect

    ## Benchmark circuit vs pipe.
    #
    # require "benchmark/ips"
    # Benchmark.ips do |x|
    #   x.report("circuit") { ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(save_circuit, {application_ctx: {params: {}, model: Object}}) }
    #   x.report("pipe")    { ctx, signal = Pipeline::Processor.(save_pipe, {application_ctx: {params: {}, model: Object}}) }

    #   x.compare!
    # end

# Learning:
##
# get rid of Pipeline. we can find a fast way to extend it at runtime.
#
# Warming up --------------------------------------
#              circuit     6.285k i/100ms
#                 pipe     7.877k i/100ms
# Calculating -------------------------------------
#              circuit     65.256k (± 2.8%) i/s -    326.820k in   5.012556s
#                 pipe     78.046k (± 1.3%) i/s -    393.850k in   5.047203s

# Comparison:
#                 pipe:    78046.2 i/s
#              circuit:    65255.8 i/s - 1.20x  (± 0.00) slower

  end

=begin
flow_options: :stack, :context_options

circuit_options: at specific points (activities) we want to make sure the steps/activities "beyond" receive certain variables.
  plus, they are immutable, all steps in one circuit receive the same set (ONLY USED FOR FUCKING exec_context and maybe one or two more)


arg = {
  ctx: {application_ctx: ..., }

  circuit_options: {exec_context: Create.new}
}


def call(ctx_for_task_invocation:, exec_context: )
  loop do
    task, invoker, circuit_options = next_for(  )

    invoker.(task, ctx.merge(circuit_options: circuit_options))
  end
end


[Create, MyInvoker, {exec_context: Create.new}] # Let Runner/Invoker add the exec_context.
  [:model, My___InstanceMethod___Step___Binary___Invoker, {}]


My___InstanceMethod___Step___Binary___Invoker(exec_context:)
  original_exec_context = exec_context


# invoker doesn't call Operation#call but grabs the @circuit

Create:
  circuit:
  exec_context:
  [invoker?]




Runner.(
  Create,
  circuit_options: {exec_context: Create.new, context_options: GLOBAL_CONTEXT_OPTIONS},
  invoker: Extract___Circuit___and___run___it, # FIXME: how to allow overriding #call?
  flow_options: {stack: []},
  application_ctx: {....},
  "before": "copy all variables",
  "after": "return original", # throw away all working variables.

    [
      {
        :model,

        "before": "{:exec_context ==> :filter_exec_context}, exec_context: InstanceMethod____Data___Behavior.new"
      }
    ]
)
=end
