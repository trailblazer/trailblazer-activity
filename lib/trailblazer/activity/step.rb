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

      def self.build_circuit(provider, binary:) # DISCUSS: allow handing in {:my_signal_fixme} ?
        adapter = provider.is_a?(Symbol) ? Circuit::Task::Adapter::StepInterface::InstanceMethod : Circuit::Task::Adapter::StepInterface

        lib_interface = Circuit::Task::Adapter::LibInterface

        steps = [
          # [:target_ctx_as_signal, Step.method(:target_ctx_as_signal), lib_interface, connections: Circuit::Resolver::Fixed.new(:invoke_provider)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
          [:invoke_provider, provider, adapter, connections: Circuit::Resolver::Fixed.new(:is_signal?)], # FIXME: is_signal? only when we want it

          # this step isn't necessary because a step, per definition, mutates the target_ctx. This is the
          # opposite of clean, but it's the API we introduced and that proved to be super handy.
          # [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.

          # DISCUSS: we could  make is_signal? configurable. That would, however, imply that the user has to decide upfront
          #          whether or not they're returning a signal instead of a booleanizable value.
          binary ? [:is_signal?, Step.method(:is_signal?), lib_interface, connections: Resolver::ValueOnSignal::Conditional.new([false], :compute_binary_signal, nil)] : nil,
          binary ? [:compute_binary_signal, Step.method(:compute_binary_signal), lib_interface, connections: Circuit::Resolver::Fixed.new(nil)] : nil,
        ].compact

        circuit = Trailblazer::Circuit::Builder.Circuit(*steps)

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

      # TODO: how could we use Node wrapping? Do we need that?
      def self.build(provider, id: :invoke_step, binary: true, node_class: Circuit::Node::MergeToCircuitOptions, **options_for_node)
        pipe =  build_circuit(provider, binary: binary)

        node_class[id, pipe, Circuit::Processor, options_for_node]
      end

      def self.compute_binary_signal(lib_ctx, flow_options, value, **)
        signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        return lib_ctx, flow_options, signal
      end

      # DISCUSS: this could be done by Node::Scoped::TargetCtx or whatever but currently
      #          i feel this is okay as a separate step.
      def self.target_ctx_as_signal(lib_ctx, flow_options, signal, **)
        target_ctx = flow_options.fetch(:application_ctx)

        return lib_ctx, flow_options, target_ctx # DISCUSS: The next node needs to be aware of the signal being the target_ctx. this is usually a provider with StepInterface.
      end

      # In a world where the step interface mutates the target_ctx, we actually don't "need"
      # this step (in a bad way, mutation sucks).
      def self.unset_target_ctx(lib_ctx, flow_options, signal, target_ctx:, **)
        flow_options = flow_options.merge(application_ctx: target_ctx)

        return lib_ctx, flow_options, signal
      end
    end # Step
  end
end
