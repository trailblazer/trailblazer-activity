module Trailblazer
  class Activity
    module Step
      # DISCUSS: should this be an instance method, too?
      class ComputeBinarySignal
        # Lib interface.
        def self.call(lib_ctx, flow_options, signal, value:, **)
          signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

          return lib_ctx, flow_options, signal
        end
      end
    end # Step
  end
end
