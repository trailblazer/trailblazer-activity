class Trailblazer::Activity
  module TaskWrap
    # TaskWrap step that calls the actual wrapped task and passes all `original_args` to it.
    #
    # It writes to wrap_ctx[:return_signal], wrap_ctx[:return_args]
    def self.call_task(wrap_ctx, original_args)
      task = wrap_ctx[:task]

      original_arguments, original_circuit_options = original_args

      # Call the actual task we're wrapping here.
      # puts "~~~~wrap.call: #{task}"
      return_signal, return_args = task.(original_arguments, **original_circuit_options)

      # DISCUSS: do we want original_args here to be passed on, or the "effective" return_args which are different to original_args now?
      wrap_ctx = wrap_ctx.merge( return_signal: return_signal, return_args: return_args )

      return wrap_ctx, original_args
    end
  end # Wrap
end
