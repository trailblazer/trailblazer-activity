module Trailblazer
  class Circuit
    class Trace
      # TODO:
      # * Struct for debug_item
      module Present
        FREE_SPACE = (' ' * 3).freeze
        module_function

        def tree(stack, level = 1)
          stack.each do |debug_item|
            puts FREE_SPACE * level + delimeter(stack, debug_item) + '--' + '> ' + to_name(debug_item) + to_options(debug_item)

            if debug_item.last.is_a?(Array)
              tree(debug_item.last, level + 1)
            end
          end
        end

        # private

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

        def delimeter(stack, debug_item)
          if stack.last == debug_item || debug_item.last.is_a?(Array)
            '`'
          else
            '|'
          end
        end
      end
    end
  end
end
