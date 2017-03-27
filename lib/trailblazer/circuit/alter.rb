module Trailblazer
  class Circuit::Activity
    def self.Alter(activity, operation, *args)
      Alter.append(activity, *args)
    end

    module Alter
      module_function

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
