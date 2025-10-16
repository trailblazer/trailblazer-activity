class Trailblazer::Activity
  module TaskWrap
    # TaskWrap step that calls the actual wrapped task and passes all `original_args` to it.
    #
    # It writes to wrap_ctx[:return_signal], wrap_ctx[:return_args]
    def self.call_task(wrap_ctx, flow_options, **)
      task = wrap_ctx[:task]

      original_ctx, original_circuit_options = wrap_ctx[:original_ctx], wrap_ctx[:original_circuit_options]

      # Call the actual task we're wrapping here.
      # puts "~~~~wrap.call: #{task}"
      return_signal, ctx, flow_options = task.call(original_ctx, flow_options, **original_circuit_options)

      # DISCUSS: do we want original_args here to be passed on, or the "effective" return_args which are different to original_args now?
      wrap_ctx = wrap_ctx.merge(
        return_signal: return_signal,
        return_args:   [ctx, flow_options]
      )
      return wrap_ctx, flow_options
    end
  end # Wrap
end
