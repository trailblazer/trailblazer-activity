module Trailblazer
  class Activity
    module Step
      def self.build_pipeline(provider, binary:)
        adapter = provider.is_a?(Symbol) ? Circuit::Task::Adapter::StepInterface::InstanceMethod : Circuit::Task::Adapter::StepInterface

        steps = [
          [:set_target_ctx, Step.method(:set_target_ctx)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
          [:invoke_provider, provider, adapter],

          # this step isn't necessary because a step, per definition, mutates the target_ctx. This is the
          # opposite of clean, but it's the API we introduced and that proved to be super handy.
          # [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.
        ]

        steps << [:compute_binary_signal, Step.method(:compute_binary_signal)] if binary

        my_pipe = Trailblazer::Circuit::Builder.Pipeline(*steps)
      end

      def self.build(provider, id: :invoke_step, binary: true, **options_for_node)
        pipe = build_pipeline(provider, binary: binary)

        Circuit::Node::Scoped[id, pipe, Circuit::Processor, **options_for_node]
      end

      def self.compute_binary_signal(lib_ctx, flow_options, signal, value:, **)
        signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

        return lib_ctx, flow_options, signal
      end

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
