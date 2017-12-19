class Trailblazer::Activity
  module Wrap
    # TaskWrap step that calls the actual wrapped task and passes all `original_args` to it.
    #
    # It writes to wrap_ctx[:result_direction], wrap_ctx[:result_args]
    def self.call_task((wrap_ctx, original_args), **circuit_options)
      task  = wrap_ctx[:task]

      # Call the actual task we're wrapping here.
      # puts "~~~~wrap.call: #{task}"
      result_direction, result_args = task.( *original_args ) # we lose :exec_context here.

      # DISCUSS: do we want original_args here to be passed on, or the "effective" result_args which are different to original_args now?
      wrap_ctx = wrap_ctx.merge( result_direction: result_direction, result_args: result_args )

      [ Right, [ wrap_ctx, original_args ], **circuit_options ]
    end
  end # Wrap
end
