class Trailblazer::Activity
  module TaskWrap
    # TaskWrap step that calls the actual wrapped task while passing approriate arguments.
    #
    # It writes to wrap_ctx[:return_signal], wrap_ctx[:return_ctx]
    def self.call_task(ctx, flow_options, circuit_options, signal, lib_ctx, task:, **)
      # application_circuit_options = lib_ctx[:application_circuit_options] # FIXME: make this an optional feature with a different call_task.
      # We maintain an alterable {circuit_options} in the taskWrap. This allows things such as changing {:start_task}.

      # Call the actual task we're wrapping here, assuming it exposes the circuit interface.
      # puts "~~~~wrap.call: #{task}"
      ctx, flow_options, return_signal =
        task.call(
          ctx,
          flow_options,
          circuit_options
        )


      return ctx, flow_options, return_signal, lib_ctx
    end
  end
end
