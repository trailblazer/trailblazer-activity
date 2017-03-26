module Trailblazer
  class Circuit
    def self.Alter(circuit, operation, *args)
      Alter.append(circuit, *args)
    end

    module Alter
      module_function

      def append(circuit, new_function, *)
        map, stop_events, name = circuit.to_fields
        end_event = stop_events.first
        new_hash  = map.dup # TODO: deep clone.

        # find the task pointing to End.
        task, outputs = new_hash.find { |k, outputs| outputs.values.include?(end_event) }
        direction = outputs.key(end_event)

        new_hash[task] = new_hash[task].dup # FIXME: deep clone!

        new_hash[task][direction] = new_function
        new_hash[new_function] = { Right => end_event } # DISCUSS; what direction?

        Circuit.new(new_hash, stop_events, name)
      end
    end
  end
end
