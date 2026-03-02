module Trailblazer
  class Activity
    class Circuit
      module Step
        # DISCUSS: should this be an instance method, too?
        class ComputeBinarySignal
          # Lib interface.
          def self.call(ctx, lib_ctx, signal, value:, **)
            signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

            return ctx, lib_ctx, signal
          end
        end
      end
    end # Circuit
  end
end
