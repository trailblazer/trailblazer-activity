module Trailblazer
  class Circuit::Activity
    # Find all `direction` connections TO <old_task> and rewire them to new_task,
    # then connect new to old with `direction`.
    #
    # Note that {Before} with `:direction` finds the edges/connections by object identity (e.g. `Circuit::Right`).

    def self.Before(activity, old_task, new_task, direction: raise, predecessors: nil, **kws)
      Rewrite(activity, **kws) do |new_map|
        # Example graph:
        #
        # D ---Lv    End
        # A -R> B -> End
        # C ---R^
        cfg = if predecessors
          # find all ingoing arrows into {old_task} (B) that are connected to specified {predecessors} (A, D).
          predecessors.collect { |predecessor| [ predecessor, new_map[predecessor].invert[old_task] ] }
          # => [ [A, Right], [D, Left] ] (both point to B and were specified predecessors)
        else
          # find all ingoing arrows into {old_task} (B) where arrow is of type {direction} (R).
          new_map.collect { |predecessor, outputs| outputs[direction] == old_task ? [ predecessor, direction ] : nil }.compact
          # => [ [A, Right], [C, Right] ] (both point to B via a R arrow)
        end

        # rewire old_task's predecessors to new_task.
        cfg.each { |(predecessor, direction)| new_map[predecessor][direction] = new_task }

        # connect new_task --> old_task.
        new_map[new_task] = { direction => old_task }
      end
    end

    def self.Connect(activity, from, to, direction:raise)
      Rewrite(activity) do |new_map|
        new_map[from][direction] = to
      end
    end

    # Deep-clones an Activity's circuit and allows to alter its map by yielding it.
    #
    #   activity = Circuit::Activity::Rewrite(activity) do |map, evt|
    #     map[some_task] = { Circuit::Right => evt[:End] }
    #   end
    #
    # You can only add events as they might already be in use in the existing map.
    #
    # :private:
    def self.Rewrite(activity, debug:{}, events:{})
      # decompose Activity and Circuit.
      circuit, original_events = activity.values
      map, end_events, original_debug  = circuit.to_fields

      original_events = original_events.to_h
      events.each { |k, v| original_events[k] = (original_events[k] || {}).merge(v) }

      # events = events.to_h.merge(added_events) # add new events.
      debug  = original_debug.to_h.merge(debug) # add new events.

      new_map = {} # deep-dup.
      map.each { |act, outputs| new_map[act] = outputs.dup }

      # recompose to an Activity.
      # new_map is mutable.
      Circuit::Activity(debug, original_events) { |evts| yield(new_map, evts); new_map }
    end
  end
end
