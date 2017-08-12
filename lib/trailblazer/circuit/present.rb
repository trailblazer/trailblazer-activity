require "hirb"

module Trailblazer
  class Circuit
    module Trace
      # TODO:
      # * Struct for debug_item
      module Present
        module_function

        def tree(stack, level=1, tree=[])
          tree_for(stack, level, tree)

          Hirb::Console.format_output(tree, class: :tree, type: :directory)
        end

        # API HERE is: we only know the current element (e.g. task), input, output, and have an "introspection" object that tells us more about the element.
        # TODO: the debug_item's "api" sucks, this should be a struct.
        def tree_for(stack, level, tree)
          stack.each do |debug_item|
            task = debug_item[0][0]

            if debug_item.size == 2 # flat
              introspect = debug_item[0].last

              name = (node = introspect[task]) ? node[:id] : task

              tree << [ level,  name ]
            else # nesting
              tree << [ level, task ]

              tree_for(debug_item[1..-2], level + 1, tree)

              tree << [ level+1, debug_item[-1][0] ]
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
            Trailblazer::Circuit::Start => :blue,
            Trailblazer::Circuit::End   => :pink,
            Trailblazer::Circuit::Right => :green,
            Trailblazer::Circuit::Left  => :red
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
