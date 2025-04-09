module Trailblazer
  class Activity
    module Introspect
      # @private
      module Render
        module_function

        def call(activity, **options)
          nodes       = Introspect.Nodes(activity)
          circuit_map = activity.to_h[:circuit].to_h[:map]

          content = nodes.collect do |task, node|
            outgoings = circuit_map[task]

            conns = outgoings.collect do |signal, target|
              " {#{signal}} => #{inspect_with_matcher(target, **options)}"
            end

            [
              inspect_with_matcher(node.task, **options),
              conns.join("\n")
            ]
          end

          content = content.join("\n")

          "\n#{content}".gsub(/0x\w+/, "0x") # DISCUSS: use sub logic from core-utils
        end

        # If Ruby had pattern matching, this function wasn't necessary.
        def inspect_with_matcher(task, inspect_task: method(:inspect_task), inspect_end: method(:inspect_end))
          return inspect_task.(task) unless task.is_a?(Trailblazer::Activity::End)
          inspect_end.(task)
        end

        def inspect_task(task)
          task.inspect
        end

        def inspect_end(task)
          class_name = strip(task.class)
          options    = task.to_h

          "#<#{class_name}/#{options[:semantic].inspect}>"
        end

        def strip(string)
          string.to_s.sub("Trailblazer::Activity::", "")
        end
      end
    end
  end
end
