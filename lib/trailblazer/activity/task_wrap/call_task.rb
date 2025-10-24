class Trailblazer::Activity
  module TaskWrap
    # TaskWrap step that calls the actual wrapped task while passing approriate arguments.
    #
    # It writes to wrap_ctx[:return_signal], wrap_ctx[:return_ctx]
    def self.call_task(wrap_ctx, flow_options, _)
      task                        = wrap_ctx[:task]
      application_ctx             = wrap_ctx[:application_ctx]
      application_circuit_options = wrap_ctx[:application_circuit_options] # FIXME: introduce kwargs in 2nd method.

      # Call the actual task we're wrapping here.
      # puts "~~~~wrap.call: #{task}"
      ctx, flow_options, return_signal =
        task.call(
          application_ctx,
          flow_options,
          application_circuit_options # We maintain an alterable {circuit_options} in the taskWrap. This allows things such as changing {:start_task}.
        )

      wrap_ctx = wrap_ctx.merge(
        return_signal: return_signal,
        return_ctx:    ctx
      )

      return wrap_ctx, flow_options
    end
  end
end
