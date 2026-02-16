module Trailblazer
  class Activity
    # A circuit is run using {Circuit::Processor}.
    class Circuit < Struct.new(:map, :start_task_id, :termini, :config, keyword_init: true)
      # Find the next step for {current_task_id => signal}.
      # This is called in {Circuit::Processor.call}.
      def resolve(current_task_id, signal)
        return if termini.include?(current_task_id) # this is faster than any other trick I tried, with {terminus => nil} etc.

        signal_map = map[current_task_id] # assumption: ID must always be a symbol.
# puts "@@@@@ #{current_task_id.inspect}, #{signal_map}"
        # return if signal_map == :terminus

        next_task_id = signal_map[signal] or raise signal.inspect # this will be nil for a terminus.

        config[next_task_id] # TODO: can we save this lookup and optimize the map directly?
      end



      # def start_for
      #   return termini, *config[start_task_id]
      # end

      def to_a_FIXME
        config[start_task_id]
      end
    end
  end
end
