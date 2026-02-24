module Trailblazer
  class Activity
    # A circuit is run using {Circuit::Processor}.
    class Circuit < Struct.new(:map, :start_task_id, :termini, :config, keyword_init: true)
      # DISCUSS: do we need a config after all? or can we infer such thing from the flow_map?
      def self.build(flow_map:, config:)
        # Init logic, done when compiling Activitys and
        # when extending ciruits via :wrap_runtime.
        ids           = flow_map.keys
        start_task_id = ids[0]
        termini       = [ids[-1]] # FIXME: test that!

        new(
          map:            flow_map,
          config:         config,
          start_task_id:  start_task_id,
          termini:        termini,
        )
      end

      # Find the next step for {current_task_id => signal}.
      # This is called in {Circuit::Processor.call}.
      def resolve(current_task_id, signal)
        return if termini.include?(current_task_id) # this is faster than any other trick I tried, with {terminus => nil} etc.

        # This lookup will always succeed unless something is entirely wrong.
        signal_map = map[current_task_id] # assumption: ID must always be a symbol.
# puts "circuit ~~~~~~ current_task_id #{current_task_id.inspect}, Signal<#{signal.inspect}> #{signal_map}"
        # return if signal_map == :terminus

        next_task_id = signal_map[signal] or raise "#{current_task_id}===>#{signal.inspect} @ #{signal_map}".inspect # this will be nil for a terminus.

        config[next_task_id] # TODO: can we save this lookup and optimize the map directly?
      end



      # def start_for
      #   return termini, *config[start_task_id]
      # end

      def to_a_FIXME
        config[start_task_id]
      end
    end # Circuit
  end
end
# TODO: map should be named flow_map
# config => tasks_attributes?
