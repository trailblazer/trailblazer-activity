module Trailblazer
  class Activity
    module Step

      module Resolver # FIXME: move to {circuit}?
        module ValueOnSignal
          class Conditional < Circuit::Resolver::Conditional
            def fetch(signal)
              decider_signal, value = signal

              super(decider_signal, value)
            end
          end
        end
      end

      def self.build_circuit(provider, adapter, binary:) # DISCUSS: allow handing in {:my_signal_fixme} ?
        steps = [
          # [:target_ctx_as_signal, Step.method(:target_ctx_as_signal), lib_interface, connections: Circuit::Resolver::Fixed.new(:invoke_provider)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
          [:invoke_provider, provider, adapter, connections: Circuit::Resolver::Fixed.new(:is_signal?)], # FIXME: is_signal? only when we want it

          # this step isn't necessary because a step, per definition, mutates the target_ctx. This is the
          # opposite of clean, but it's the API we introduced and that proved to be super handy.
          # [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.

          # DISCUSS: we could  make is_signal? configurable. That would, however, imply that the user has to decide upfront
          #          whether or not they're returning a signal instead of a booleanizable value.
          binary ? [:is_signal?, Step.method(:is_signal?), connections: Resolver::ValueOnSignal::Conditional.new([false], :compute_binary_signal, nil)] : nil,
          binary ? [:compute_binary_signal, Step.method(:compute_binary_signal), connections: Circuit::Resolver::Fixed.new(nil)] : nil,
        ].compact

        circuit = Circuit::Builder.Circuit(*steps)

        return circuit
      end
      # DISCUSS: we got a special Resolver for {is_signal?} that can handle the
      #          combined signal.
      def self.is_signal?(lib_ctx, flow_options, value, **)
        if value.is_a?(Class) && value < (Activity::Signal)
          return lib_ctx, flow_options, [true, value] # FIXME: this output must be configured as a terminus.
        end

        return lib_ctx, flow_options, [false, value] # DISCUSS: false implies "we have to go to compute_binary_signal"
      end

      # FIXME: if we decide for **circuit_options, this shouldn't build MergeToCircuitOptions when no exec_context needed!
      def self.build(provider, id: :invoke_step, binary: true, node_class: Circuit::Node::MergeToCircuitOptions, exec_context: nil, options: {}, **options_for_node)
        adapter, requires_exec_context =
          provider.is_a?(Symbol) ? [Circuit::Task::Adapter::StepInterface::InstanceMethod, true] : [Circuit::Task::Adapter::StepInterface]

        pipe = build_circuit(provider, adapter, binary: binary)

        options = options.merge(requires_exec_context: requires_exec_context)

        # Let the builder figure out whether we want a Node or a Node::MergeToCircuitOptions (depending on :exec_context).
        Circuit::Builder.Node(pipe, Circuit::Processor, exec_context: exec_context, options: options, **options_for_node)
      end

      def self.compute_binary_signal(lib_ctx, flow_options, value, **)
        signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        return lib_ctx, flow_options, signal
      end
    end # Step
  end
end
