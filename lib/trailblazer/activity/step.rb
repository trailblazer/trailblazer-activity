module Trailblazer
  class Activity
    module Step

      module Resolver # FIXME: move to {circuit}?
        module ValueOnSignal
          class Conditional < Struct.new(:known_signals, :id_for_known_signal, :id_for_else)
            def fetch(signal)
              decider_signal, value = signal

              if known_signals.include?(decider_signal)
                return id_for_known_signal, value
              end
# raise "do we want such complex Resolvers?"
              return id_for_else, value
            end
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

      def self.build(provider, id: :invoke_step, binary: true, **options_for_node)
        pipe =  build_circuit(provider, binary: binary)

        Circuit::Node::Scoped[id, pipe, Circuit::Processor, **options_for_node] # DISCUSS: do we need Scoped for the provider invocation?
      end

      def self.compute_binary_signal(lib_ctx, flow_options, value, **)
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



      def self.build_with_value_on_signal(provider)
        pipe =  build_circuit_(provider, binary: binary)

        Circuit::Node[id, pipe, Circuit::Processor, **options_for_node] # DISCUSS: with Node and no Scoped, we cannot set exec_context locally.
      end

      class MyStepInterface
        def self.call(task, lib_ctx, flow_options, signal, **circuit_options)
            target_ctx = lib_ctx.fetch(:target_ctx) # TODO: introduce second kwargs method that calls {#run_step}.

            result = run_step(task, target_ctx, **lib_ctx)

            return lib_ctx, flow_options, result
          end

          def self.run_step(task, target_ctx, **)
            task.(target_ctx, **target_ctx.to_h)
          end
      end

      def self.build_circuit_(provider, binary:) # DISCUSS: allow handing in {:my_signal_fixme} ?
        # adapter = provider.is_a?(Symbol) ? Circuit::Task::Adapter::StepInterface::InstanceMethod : Circuit::Task::Adapter::StepInterface
        adapter = provider.is_a?(Symbol) ? Circuit::Task::Adapter::StepInterface::InstanceMethod : MyStepInterface

        lib_interface = Circuit::Task::Adapter::LibInterface

        steps = [
          [:set_target_ctx, Step.method(:set_target_ctx), lib_interface, connections: Circuit::Resolver::Fixed.new(:invoke_provider)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
          [:invoke_provider, provider, adapter, connections: Resolver::Fixed.new(:is_signal?)],

          # this step isn't necessary because a step, per definition, mutates the target_ctx. This is the
          # opposite of clean, but it's the API we introduced and that proved to be super handy.
          # [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.

          # DISCUSS: we could  make is_signal? configurable. That would, however, imply that the user has to decide upfront
          #          whether or not they're returning a signal instead of a booleanizable value.
          binary ? [:is_signal?, Step.method(:___is_signal?), lib_interface, connections: Resolver::Conditional.new([false], :compute_binary_signal, nil)] : nil,
          binary ? [:compute_binary_signal, Step.method(:compute_binary_signal_), lib_interface, connections: Circuit::Resolver::Fixed.new(nil)] : nil,
        ].compact

        circuit = Trailblazer::Circuit::Builder.Circuit(*steps)

        return circuit
      end

      def self.___is_signal?(lib_ctx, flow_options, value, **) # left means it's a signal
        if value.is_a?(Class) && value < (Activity::Signal)
          return lib_ctx, flow_options, value # FIXME: this output must be configured as a terminus.
        end

        return lib_ctx, flow_options, false # DISCUSS: false implies "we have to go to compute_binary_signal"
      end


    end # Step
  end
end
