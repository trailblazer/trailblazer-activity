module Trailblazer
  class Activity
    module Step
# raise "could we pass the step-returned signal not as value but as signal, and then skip the is_signal? step with proper routing?"

      module Resolver # FIXME: move to {circuit}?
        class Conditional < Struct.new(:known_signals, :default_id, :fallback_id)
          def fetch(signal)
            if known_signals.include?(signal)
              return default_id
            end

            return fallback_id
          end
        end
      end

      def self.build_circuit(provider, binary:) # DISCUSS: allow handing in {:my_signal_fixme} ?
        adapter = provider.is_a?(Symbol) ? Circuit::Task::Adapter::StepInterface::InstanceMethod : Circuit::Task::Adapter::StepInterface

        lib_interface = Circuit::Task::Adapter::LibInterface

        steps = [
          [:set_target_ctx, Step.method(:set_target_ctx), lib_interface, connections: Circuit::Resolver::Fixed.new(:invoke_provider)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
          [:invoke_provider, provider, adapter, connections: Circuit::Resolver::Fixed.new(:is_signal?)],

          # this step isn't necessary because a step, per definition, mutates the target_ctx. This is the
          # opposite of clean, but it's the API we introduced and that proved to be super handy.
          # [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.

          binary ? [:is_signal?, Step.method(:is_signal?), lib_interface, connections: Resolver::Conditional.new([false], :compute_binary_signal, nil)] : nil,
          binary ? [:compute_binary_signal, Step.method(:compute_binary_signal), lib_interface, connections: Circuit::Resolver::Fixed.new(nil)] : nil,
        ].compact

        circuit = Trailblazer::Circuit::Builder.Circuit(*steps)

        return circuit
      end

      def self.is_signal?(lib_ctx, flow_options, signal, value:, **)
        if value.is_a?(Class) && value < (Activity::Signal)
          return lib_ctx, flow_options, value # FIXME: this output must be configured as a terminus.
        end

        return lib_ctx, flow_options, false # DISCUSS: false implies "we have to go to compute_binary_signal"
      end

      def self.build(provider, id: :invoke_step, binary: true, **options_for_node)
        pipe =  build_circuit(provider, binary: binary)

        Circuit::Node::Scoped[id, pipe, Circuit::Processor, **options_for_node]
      end

      def self.compute_binary_signal(lib_ctx, flow_options, signal, value:, **)
        signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        return lib_ctx, flow_options, signal
      end

      # DISCUSS: this could be done by Node::Scoped::TargetCtx or whatever but currently
      #          i feel this is okay as a separate step.
      def self.set_target_ctx(lib_ctx, flow_options, signal, **)
        lib_ctx = lib_ctx.merge(target_ctx: flow_options.fetch(:application_ctx))

        return lib_ctx, flow_options, signal
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
