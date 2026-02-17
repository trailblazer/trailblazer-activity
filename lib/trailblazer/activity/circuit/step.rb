module Trailblazer
  class Activity
    class Circuit
      module Step
        # DISCUSS: should this be an instance method, too?
        class ComputeBinarySignal
          # Lib interface.
          def self.call(ctx, lib_ctx, value:, **)
            signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

            lib_ctx[:signal] = signal

            return ctx, lib_ctx, nil
          end
        end
      end
    end # Circuit
  end
end
