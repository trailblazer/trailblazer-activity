module Trailblazer
  class Activity
    module Invoke
      module_function

      def compute_id(lib_ctx, flow_options, signal, node:, id: nil, **)
        id = node.task.inspect if id.nil?

        return lib_ctx.merge(id: id), flow_options
      end

      def produce_lib_ctx(lib_ctx, flow_options, _, target_ctx:, **) # DISCUSS: do we need this step?
        lib_ctx_for_invoke = {lib_ctx: {target_ctx: target_ctx}}

        return lib_ctx.merge(lib_ctx: lib_ctx_for_invoke)
      end

      # The canonical invoke. Usually used by the user when doing Operation.().
      def call(circuit, lib_ctx, compiler: Args::Compiler, runner: Circuit::WrapRuntime::Runner, flow_options: {}, **circuit_options)
        circuit_options = circuit_options.merge(circuit: circuit)

        lib_ctx, flow_options, circuit_options = Circuit::Processor.(compiler, lib_ctx, flow_options, circuit_options, runner: Circuit::Node::Runner)



        # raise options_ctx.inspect
        signal = nil

        invoke_runner(
          lib_ctx, flow_options, signal,
          # FIXME: where to do this?
          # wrap_runtime: Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions),
          runner: runner,
          **circuit_options
        )
      end

      def build_activity_node(lib_ctx, flow_options, circuit_options, **)
        circuit = circuit_options.fetch(:circuit)

        activity_node = Circuit::Node[circuit, Circuit::Processor] # DISCUSS: should that be done on the outside? should WTF pass the Node class here?

        return lib_ctx, flow_options, circuit_options.merge(node: activity_node)
      end

      def build_canonical_node(lib_ctx, flow_options, circuit_options, **)
        node = circuit_options.fetch(:node)

        # build the canonical pipeline.
        canonical_pipeline = Circuit::Builder.Pipeline(
          [:"task_wrap.call_task", node: node]
        )

        # the canonical node usually represents some kind of task_wrap.
        # TODO: allow mixing in task_wrap_extensions a la Subprocess from the "circuit"
        node = Circuit::Node[canonical_pipeline, Circuit::Processor]

        return lib_ctx, flow_options, circuit_options.merge(node: node) # DISCUSS: introduce Adapter::Invoke ?
      end

      # DISCUSS: location?
      # DISCUSS: this is generic for the WrapRuntime layer, not for trace/wtf, only.
      def produce_wrap_runtime(lib_ctx, flow_options, circuit_options, **)
        extensions = circuit_options.fetch(:extensions)

        extensions = Circuit::WrapRuntime::Extension::Set.new(
          [
            Circuit::WrapRuntime::Extension::NodeWrap, # TODO: don't add that when we don't have any extensions!
            *extensions,
          ]
        )

        wrap_runtime = Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(extensions)

        return lib_ctx, flow_options, circuit_options.merge(wrap_runtime: wrap_runtime) # NOTE: we don't pass on {:extensions} here.
      end

      def invoke_runner(lib_ctx, flow_options, signal, runner:, **circuit_options)
        lib_ctx, flow_options, signal = runner.(
          lib_ctx,
          flow_options,
          signal,
          context_implementation: Trailblazer::Circuit::Context,
          **circuit_options,
          runner: runner
        )
      end

      module Args
        Compiler = Circuit::Builder.Pipeline(
          # [:compute_id, method(:compute_id)],
          # [:produce_lib_ctx, method(:produce_lib_ctx)],
          [:build_activity_node, Invoke.method(:build_activity_node)],
          [:build_canonical_node, Invoke.method(:build_canonical_node)],
          # in canonical invoke, this could be part of the pipe.
          # lib_ctx, flow_options, signal, circuit_options = _FIXME_add_options_for_trace(lib_ctx, flow_options, signal, **circuit_options)
          #
          # this is now specific to WrapRuntime
          [:produce_wrap_runtime, Invoke.method(:produce_wrap_runtime)],
        )
      end
    end
  end
end
