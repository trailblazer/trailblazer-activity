module Trailblazer
  class Activity
    # A circuit is run using {Circuit::Processor}.
    class Circuit < Struct.new(:map, :start_task_id, :termini, :config, keyword_init: true)
      # Find the next step for {current_task_id => signal}.
      # This is called in {Circuit::Processor.call}.
      def resolve(current_task_id, signal)
        signal_map = map[current_task_id]# or return false # assumption: ID must always be a symbol.
        next_task_id = signal_map[signal]

        config[next_task_id]
      end

      def start_for
        return termini, *config[start_task_id]
      end

      def to_a_FIXME
        return termini, config[start_task_id]
      end
    end
  end
end
