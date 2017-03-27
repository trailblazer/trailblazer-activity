module Trailblazer
  class Circuit::Activity
    def self.Alter(activity, operation, *args)
      return Alter.before(activity, *args) if operation == :before
      Alter.append(activity, *args)
    end

    module Alter
      module_function

      def before(activity, old_task, new_task, direction:)
        # find all <direction> lines TO <old_task> and rewire them to new_task, then connect
        # new to old with <direction>.

        circuit, events = activity.values
        map, end_events, name  = circuit.to_fields # FIXME: there's some redundancy with
        # the end events in Circuit and Activity.

        new_activity = {} # FIXME: deepdup.
        map.each { |act, outputs| new_activity[act] = outputs.dup }

        cfg = new_activity.find_all { |act, outputs| outputs[direction]==old_task }

        # rewire old line to new task.
        cfg.each { |(activity, outputs)| outputs[direction] = new_task }
        # connect new_task --> old_task.
        new_activity[new_task] = { direction => old_task }


        circuit = Circuit.new(new_activity, end_events, name) # FIXME: this sucks!
        Trailblazer::Circuit::Activity.new(circuit, events)
      end

      def append(activity, new_function, end_event: :default, **options)
        circuit, events = activity.values
        map, end_events, name  = circuit.to_fields # FIXME: there's some redundancy with
        # the end events in Circuit and Activity.

        end_event = events[:End, end_event]

        new_hash  = map.dup # TODO: deep clone.

        # find the task pointing to End.
        task, outputs = new_hash.find { |k, outputs| outputs.values.include?(end_event) }
        direction = outputs.key(end_event)

        new_hash[task] = new_hash[task].dup # FIXME: deep clone!

        new_hash[task][direction] = new_function
        new_hash[new_function] = { direction => end_event } # DISCUSS; what direction?

        circuit = Circuit.new(new_hash, end_events, name) # FIXME: this sucks!
        Trailblazer::Circuit::Activity.new(circuit, events)
      end
    end
  end
end
