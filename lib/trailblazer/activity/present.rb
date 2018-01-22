require "hirb"

module Trailblazer
  class Activity < Module
    module Trace
      # TODO: make this simpler.
      module Present
        module_function

        def tree(stack, level=1, tree=[])
          tree_for(stack, level, tree)

          Hirb::Console.format_output(tree, class: :tree, type: :directory)
        end

        def tree_for(stack, level, tree)
          stack.each do |captured, *returned|
            task = captured.task

            name = (node = captured.introspection[task]) ? node[:id] : task

            if returned.size == 1 # flat
              tree << [ level, name ]
            else # nesting
              tree << [ level, name ]

              tree_for(returned[0..-2], level + 1, tree)
            end

            tree
          end
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
