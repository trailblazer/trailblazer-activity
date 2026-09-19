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

      Options = Circuit::Builder.Pipeline(
        [:compute_id, method(:compute_id)],
        [:produce_lib_ctx, method(:produce_lib_ctx)],
      )



      # The canonical invoke. Usually used by the user when doing Operation.().
      def call(circuit, lib_ctx, options_compiler: Options, runner: Circuit::WrapRuntime::Runner, flow_options: {}, **circuit_options)
        # TODO: make this a pipe?
        # options_ctx = {target_ctx: target_ctx, node: activity_node, flow_options: {}, signal: nil}

        # DISCUSS: in Processor, we don't allow passing on circuit_options. however, it's so cute an simple to just pass those
        #          arguments onwards.
        lib_ctx, flow_options, signal, circuit_options = build_activity_node(lib_ctx, flow_options, nil, runner: runner, circuit: circuit, **circuit_options)
        lib_ctx, flow_options, signal, circuit_options = build_canonical_node(lib_ctx, flow_options, signal, **circuit_options)

        # in canonical invoke, this could be part of the pipe.
        # lib_ctx, flow_options, signal, circuit_options = _FIXME_add_options_for_trace(lib_ctx, flow_options, signal, **circuit_options)

        # this is now specific to WrapRuntime
        lib_ctx, flow_options, signal, circuit_options = produce_wrap_runtime(lib_ctx, flow_options, signal, **circuit_options)


# TODO: add that in the canonical invoke
        # options_ctx, _ = Circuit::Processor.(options_compiler, options_ctx, {}, nil, runner: Circuit::Node::Runner)




        # raise options_ctx.inspect

        invoke_runner(
          lib_ctx, flow_options, signal,
          # FIXME: where to do this?
          # wrap_runtime: Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions),
          **circuit_options
        )
      end

      def build_activity_node(*args, circuit:, **circuit_options)
        activity_node = Circuit::Node[circuit, Circuit::Processor] # DISCUSS: should that be done on the outside? should WTF pass the Node class here?

        return *args, circuit_options.merge(node: activity_node)
      end

      def build_canonical_node(*args, node:, **circuit_options)
        # build the canonical pipeline.
        canonical_pipeline = Circuit::Builder.Pipeline(
          [:"task_wrap.call_task", node: node]
        )

        # the canonical node usually represents some kind of task_wrap.
        # TODO: allow mixing in task_wrap_extensions a la Subprocess from the "circuit"
        node = Circuit::Node[canonical_pipeline, Circuit::Processor]

        return *args, circuit_options.merge(node: node)
      end

      # DISCUSS: location?
      # DISCUSS: this is generic for the WrapRuntime layer, not for trace/wtf, only.
      def produce_wrap_runtime(*args, extensions:, **circuit_options)
        extensions = Circuit::WrapRuntime::Extension::Set.new(
          [
            Circuit::WrapRuntime::Extension::NodeWrap,
            *extensions,
          ]
        )

        wrap_runtime = Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(extensions)

        return *args, circuit_options.merge(wrap_runtime: wrap_runtime) # NOTE: we don't pass on {:extensions} here.
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

      # def FIXME_additionals
      #   # my_wtf_circuit_fixme = Trailblazer::Circuit::Builder.Pipeline(
      #   #   [:wtf_top_canonical, node: my_canonical_Create_tw_node]
      #   # )
      #   # my_wtf_node = Trailblazer::Developer::Wtf::Node[my_wtf_circuit_fixme, Trailblazer::Circuit::Processor]

      #   # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
      #   my_tracing_extension = Trailblazer::Circuit::WrapRuntime.Extension(adds: Trailblazer::Developer::Trace::Extension) # WrapRuntime::Extension means we adds

      #   my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      #     [
      #       Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
      #       my_tracing_extension,
      #     ]
      #   )

      #   flow_options = {
      #     stack:              Trailblazer::Developer::Trace::Stack.new,
      #     value_snapshooter:  Trailblazer::Developer::Trace.value_snapshooter
      #   }

      #   wrap_runtime: Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver.new(my_extensions),
      # end
    end
  end
end
