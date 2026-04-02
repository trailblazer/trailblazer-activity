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

      def self.set_target_ctx(lib_ctx, flow_options, signal, **)
        lib_ctx = lib_ctx.merge(target_ctx: flow_options.fetch(:application_ctx))

        return lib_ctx, flow_options, signal
      end

      def self.unset_target_ctx(lib_ctx, flow_options, signal, target_ctx:, **)
        flow_options = flow_options.merge(application_ctx: target_ctx)

        return lib_ctx, flow_options, signal
      end
    end # Step
  end
end
