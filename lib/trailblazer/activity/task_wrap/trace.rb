class Trailblazer::Activity < Module
  module TaskWrap
    # TaskWrap tasks for tracing.
    module Trace
      # def self.capture_args(direction, options, flow_options, wrap_config, original_flow_options)
      def self.capture_args((wrap_config, original_args), **circuit_options)
        (original_options, original_flow_options), original_circuit_options = original_args

        original_flow_options[:stack].indent!

        original_flow_options[:stack] << Trailblazer::Activity::Trace::Entity.new( wrap_config[:task], :args, nil, {}, original_circuit_options[:activity] )

        [ Trailblazer::Activity::Right, [wrap_config, original_args], **circuit_options ]
      end

      def self.capture_return((wrap_config, original_args), **circuit_options)
        (original_options, original_flow_options, _) = original_args[0]

        original_flow_options[:stack] << Trailblazer::Activity::Trace::Entity.new(  wrap_config[:task], :return, wrap_config[:return_signal], {} )

        original_flow_options[:stack].unindent!


        [ Trailblazer::Activity::Right, [wrap_config, original_args], **circuit_options ]
      end
    end
  end
end
