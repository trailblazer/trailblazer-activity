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
    def self.Rewrite(activity)
      # decompose Activity and Circuit.
      circuit, events = activity.values
      map, end_events, name  = circuit.to_fields

      new_map = {} # deep-dup.
      map.each { |act, outputs| new_map[act] = outputs.dup }

      yield new_map # new_map is mutable.

      # recompose to an Activity.
      circuit = Circuit.new(new_map, end_events, name)
      Circuit::Activity.new(circuit, events)
    end
  end
end
