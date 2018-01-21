module Trailblazer::Activity
  module Magnetic
    module Merge
      # THIS IS HIGHLY EXPERIMENTAL AS WE'RE NOT MERGING taskWrap etc.
      def merge!(merged)
        merged_adds = Builder.merge(@adds, merged.instance_variable_get(:@adds))
        # TODO: MERGE DEBUG, TASK_WRAP
        builder, @adds, @circuit, @outputs, = State.recompile(@builder, merged_adds)

        self
      end
    end
  end
end
