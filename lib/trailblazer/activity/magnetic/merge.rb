class Trailblazer::Activity < Module
  module Magnetic
    module Merge
      # THIS IS HIGHLY EXPERIMENTAL AS WE'RE NOT MERGING taskWrap etc.
      def merge!(merged)
        merged_adds = Builder.merge(self[:adds], merged[:adds])
        # TODO: MERGE DEBUG, TASK_WRAP
        builder, adds, circuit, outputs, = State.recompile(self[:builder], merged_adds)

        self[:adds] = adds
        self[:circuit] = circuit
        self[:outputs] = outputs

        self
      end
    end
  end
end
