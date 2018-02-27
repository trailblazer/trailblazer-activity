module Trailblazer
  class Activity < Module
    module DSL
      # {:extension API}
      # Record each DSL call (like #step) on the activity.
      def self.record(activity, *args, original_dsl_args:)
        activity[:record, original_dsl_args[1]] = original_dsl_args
      end
    end
  end
end
