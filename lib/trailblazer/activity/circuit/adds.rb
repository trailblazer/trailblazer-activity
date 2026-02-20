module Trailblazer
  class Activity
    class Circuit
      # Insert, replace or delete tasks in an Activity::Circuit.
      module Adds
        # Implements the Friendly interface™. (not so friendly anymore...)
        #
        # Since we're using this to implement {:wrap_runtime}, this has to be fast.
        # It is also used at compile-time, though.
        def self.call(circuit, *instructions)
          blaaaaaa_FIXME = circuit.to_h
          flow_map = blaaaaaa_FIXME[:map]

          start_id, last_id = circuit[:start_task_id], circuit[:termini].last

          signal_to_repoint = nil # FIXME.

          new_tasks = []

          instructions.each do |(id, *args), insertion_method, target_id|
            flow_map, start_id, last_id = send(insertion_method, flow_map, id, signal_to_repoint, target_id, start_id, last_id)
            new_tasks << [id, [id, *args]] # FIXME: * is slow.
          end


          config = blaaaaaa_FIXME[:config].merge(new_tasks.to_h)

          circuit.class.build(flow_map: flow_map, config: config).tap do |o|
            pp o
          end
        end

        def self.before(flow_map, inserted, signal_to_repoint, target_id, start_id, last_id)
            target_index = 0
          if target_id.nil? # new start task coming.
            target_id = start_id
            start_id = inserted
          else
            to_merge = {}

            # First, re-point the predecessor of target to the newly inserted.
            flow_map.each_with_index do |(id, connections), index|
              target = connections[signal_to_repoint]

              if target == target_id
                target_index = index + 1
                to_merge = {id => connections.merge(signal_to_repoint => inserted)}
                break
              end
            end

            flow_map = flow_map.merge(**to_merge)
          end

          # Since we have to ensure the correct order in flow_map, we switch
          # to array representation here for correct insertion position.
          flow_map = insert_at(flow_map, target_index, [inserted, {signal_to_repoint => target_id}])

          return flow_map, start_id, last_id
        end

        def self.after(flow_map, inserted, signal_to_repoint, target_id, start_id, last_id)
          if target_id.nil?
            target_id = last_id
            last_id = inserted
          end

          old_connections = flow_map[target_id]

          # TIL #merge reuses the old position of the key!
          flow_map = flow_map.merge(
            target_id => old_connections.merge(signal_to_repoint => inserted),
          )

          target_index = flow_map.keys.index(target_id) + 1

          flow_map = insert_at(flow_map, target_index, [inserted, {signal_to_repoint => old_connections[signal_to_repoint]}])

# pp flow_map
# raise

          return flow_map, start_id, last_id
        end

        # @private
        def self.insert_at(flow_map, target_index, element)
          flow_ary = flow_map.to_a
          flow_ary = flow_ary.insert(target_index, element)
          flow_map = flow_ary.to_h
        end
      end
    end # Circuit
  end
end
