module Trailblazer
  class Circuit
    class Presenter
      FREE_SPACE = (' ' * 3).freeze

      def tree(stack, level = 1)
        stack.each do |item|
          puts FREE_SPACE * level + delimeter(stack, item) + '--' + '> ' + colorify(item)

          if item.last.is_a?(Array)
            tree(item.last, level + 1)
          end
        end
      end

      private

      def colorify(item)
        track = item[2]
        klass = track.class == Class ? track : track.class
        color = color_map[klass]

        return item[0].to_s unless color

        "\e[#{color_table[color]}m#{item[0]}\e[0m"
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

      def delimeter(stack, item)
        if stack.last == item || item.last.is_a?(Array)
          '`'
        else
          '|'
        end
      end
    end
  end
end
