module Trailblazer
  class Circuit::Activity
    # Find all `direction` connections TO <old_task> and rewire them to new_task,
    # then connect new to old with `direction`.
    def self.Before(activity, old_task, new_task, direction:)
      Rewrite(activity) do |new_map|
        cfg = new_map.find_all { |act, outputs| outputs[direction]==old_task }
        # rewire old line to new task.
        cfg.each { |(activity, outputs)| outputs[direction] = new_task }
        # connect new_task --> old_task.
        new_map[new_task] = { direction => old_task }
      end
    end

    def self.Connect(activity, from, direction, to)
      Rewrite(activity) do |new_map|
        new_map[from][direction] = to
      end
    end

    # Deep-clones an Activity's circuit and allows to alter its map by yielding it.
    #
    # :private:
    def self.Rewrite(activity, additional_events={})
      # decompose Activity and Circuit.
      circuit, events = activity.values
      events = events.to_h.merge(additional_events)
      map, end_events, name  = circuit.to_fields

      new_map = {} # deep-dup.
      map.each { |act, outputs| new_map[act] = outputs.dup }

      # recompose to an Activity.
      # new_map is mutable.
      Circuit::Activity(name, events) { |evts| yield(new_map, evts); new_map }
    end
  end
end
