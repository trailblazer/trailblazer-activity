class Trailblazer::Activity < Module
  module TaskWrap
    # TaskWrap tasks for tracing.
    module Trace
      module_function

      # taskWrap step to capture incoming arguments of a step.
      # def self.capture_args(direction, options, flow_options, wrap_config, original_flow_options)
      def capture_args((wrap_config, original_args), **circuit_options)

        original_args = capture_for(wrap_config[:task], *original_args)

        return Trailblazer::Activity::Right, [wrap_config, original_args], circuit_options
      end

      # taskWrap step to capture outgoing arguments from a step.
      def capture_return((wrap_config, original_args), **circuit_options)
        (original_options, original_flow_options, _) = original_args[0]

        original_flow_options[:stack] << Trailblazer::Activity::Trace::Entity::Output.new(
          wrap_config[:task], {}, wrap_config[:return_signal]
        ).freeze

        original_flow_options[:stack].unindent!


        return Trailblazer::Activity::Right, [wrap_config, original_args], circuit_options
      end

      # It's important to understand that {flow[:stack]} is mutated by design. This is needed so
      # in case of exceptions we still have a "global" trace - unfortunately Ruby doesn't allow
      # us a better way.
      def capture_for(task, (ctx, flow), activity:, **circuit_options)
        flow[:stack].indent!

        flow[:stack] << Trailblazer::Activity::Trace::Entity::Input.new(
          task, activity
        ).freeze

        return [ctx, flow], circuit_options.merge(activity: activity)
      end
    end
  end
end
