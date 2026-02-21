module Trailblazer
  class Activity
    class Circuit
      # Insert, replace or delete tasks in an Activity::Circuit.
      module Adds
        # Implements the Friendly interface™. (not so friendly anymore...)
        #
        # Since we're using this to implement {:wrap_runtime}, this has to be fast.
        # It is also used at compile-time, though.
        #
        # Feel free to benchmark and optimize this!
        def self.call(circuit, *instructions)
          blaaaaaa_FIXME = circuit.to_h
          flow_map = blaaaaaa_FIXME[:map]
          config = blaaaaaa_FIXME[:config]

          # Passing around start_id and last_id is for internal "caching" and part of this algorithm, not of the Circuit building.
          instructions.each do |task_args, insertion_method, target_id|
            flow_map, config = send(insertion_method, flow_map, config, task_args, target_id)
            # new_tasks << [id, [id, *args]] # FIXME: * is slow. # FIXME: deleted tasks will still hang out in config. is that a problem?
          end


          # config = blaaaaaa_FIXME[:config].merge(new_tasks.to_h)mmmmmmmmmmmmm

          circuit.class.build(flow_map: flow_map, config: config) # this will recompute start and termini.
        end

        # TODO: generic Insert logic.

        def self.before(flow_map, config, args_for_inserted, target_id, signal_to_repoint = nil)
          inserted_id = args_for_inserted[0]
          config = config.merge(inserted_id => args_for_inserted) # DISCUSS: we kind of have to do that here.
          flow_ary_keys = flow_map.keys

          if target_id.nil? # new start task coming.
            target_index = 0
            target_id = flow_ary_keys[target_index]
          else
            to_merge = {}

            # First, re-point the predecessor of target to the newly inserted.
            flow_map.each_with_index do |(id, connections), index|
              target = connections[signal_to_repoint]

              if target == target_id
                target_index = index + 1
                to_merge = {id => connections.merge(signal_to_repoint => inserted_id)}
                break
              end
            end

            flow_map = flow_map.merge(**to_merge)
          end

          # Since we have to ensure the correct order in flow_map, we switch
          # to array representation here for correct insertion position.
          flow_map = insert_at(flow_map, target_index, [inserted_id, {signal_to_repoint => target_id}])

          return flow_map, config
        end

        # raise "how does Processor compute start, how if we reached terminus? by ID or simply because there's nil?"

        def self.after(flow_map, config, args_for_inserted, target_id, signal_to_repoint = nil)
          inserted_id = args_for_inserted[0]
          config = config.merge(inserted_id => args_for_inserted) # DISCUSS: we kind of have to do that here.
          flow_ary_keys = flow_map.keys

          if target_id.nil?
            target_index = -1
            target_id = flow_ary_keys[target_index]
          else
            target_index = flow_ary_keys.index(target_id) + 1
          end

          old_connections = flow_map[target_id]

          # TIL #merge reuses the old position of the key!
          flow_map = flow_map.merge(
            target_id => old_connections.merge(signal_to_repoint => inserted_id),
          )

          flow_map = insert_at(flow_map, target_index, [inserted_id, {signal_to_repoint => old_connections[signal_to_repoint]}])

          return flow_map, config
        end

        # @private
        def self.insert_at(flow_map, target_index, element)
          flow_ary = flow_map.to_a
          flow_ary = flow_ary.insert(target_index, element)
          flow_map = flow_ary.to_h
        end

        def self.delete(flow_map, config, _, target_id, start_id, last_id, signal_to_repoint)

        end
      end
    end # Circuit
  end
end
