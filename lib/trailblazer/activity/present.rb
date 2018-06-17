require "hirb"

module Trailblazer
  class Activity < Module

    # Task < Array
    # [ input, ..., output ]

    module Trace
      # TODO: make this simpler.
      module Present
        module_function

        def call(stack, level=1, tree=[])
          tree(stack.to_a, level, tree)
        end

        def tree(stack, level, tree)
          tree_for(stack, level, tree)

          Hirb::Console.format_output(tree, class: :tree, type: :directory)
        end

        def tree_for(stack, level, tree)
          stack.each do |task| # always a Stack::Task[input, ..., output]
            input, output, nested = input_output_nested_for_task(task)

            task = input.task

            graph = Introspect::Graph(input.activity)

            name = (node = graph.find { |node| node[:task] == task }) ? node[:id] : task
            name ||= task # FIXME: bullshit

            tree << [ level, name ]

            if nested.any? # nesting
              tree_for(nested, level + 1, tree)
            end

            tree
          end
        end

        # DISCUSS: alternatively, we can have Task<input: output: data: >
        def input_output_nested_for_task(task)
          input  = task[0]
          output = task[-1]

          output, nested = output.is_a?(Entity::Output) ? [output, task-[input, output]] : [nil, task[1..-1]]

          return input, output, nested
        end

        def to_name(debug_item)
          track = debug_item[2]
          klass = track.class == Class ? track : track.class
          color = color_map[klass]

          return debug_item[0].to_s unless color
          colorify(debug_item[0], color)
        end

        def to_options(debug_item)
          debug_item[4]
        end



        def colorify(string, color)
          "\e[#{color_table[color]}m#{string}\e[0m"
        end

        def color_map
          {
            Trailblazer::Activity::Start => :blue,
            Trailblazer::Activity::End   => :pink,
            Trailblazer::Activity::Right => :green,
            Trailblazer::Activity::Left  => :red
          }
        end

        def color_table
          {
            red:    31,
            green:  32,
            yellow: 33,
            blue:   34,
            pink:   35
          }
        end
      end
    end
  end
end
