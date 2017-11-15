# TODO: delete

module Trailblazer
  module Activity::Magnetic

    class Alterations # used directly in Magnetic::DSL
      def initialize
        @groups = Activity::Schema::Magnetic::Dependencies.new
        @future_magnetic_to = {} # DISCUSS: future - should it be here?
      end

      # @param options Array [ [:success], task, { Right: :success } ]
      def add(id, options, **sequence_options)
        @groups.add(id, options, **sequence_options)

        # DISCUSS: future - should it be here?
        if magnetic_to = @future_magnetic_to.delete(id)
          magnetic_to( id, magnetic_to )
        end

        self
      end

      # def connect_to(id, connect_to)
      #   group, index = @groups.find(id)

      #   arr = group[index].configuration.dup

      #   connect_to.each do |semantic, color|
      #     i = arr[2].find_index { |out| out.semantic == semantic }
      #     output = arr[2][i]

      #     arr[2][i] = Activity::Magnetic.Output(output.signal, color, output.semantic)
      #   end

      #   group.add(id, arr, replace: id)
      # end

      def magnetic_to(id, magnetic_to)
        group, index = @groups.find(id) # this can be a future task!

        unless group # DISCUSS: future - should it be here?
          @future_magnetic_to[id] = magnetic_to
          return
        end

        arr = group[index].configuration.dup

        arr[0] = arr[0] + magnetic_to
        group.add(id, arr, replace: id)
      end

      # [[[:success],
      #   DrawGraphTest::A,
      #   {:success=>:success, :failure=>:failure},
      #   {:Right=>:success, :Left=>:failure}],
      #  [[:failure],
      #   DrawGraphTest::E,
      #   {:success=>"e_to_success", :failure=>:failure},
      #   {:Right=>:success, :Left=>:failure}],
      #  [[:failure], DrawGraphTest::EF, {}, {}],
      #  [[:success, "e_to_success"], DrawGraphTest::ES, {}, {}]]
      def to_a
        @groups.to_a
      end
    end # Alterations
  end

  class Activity::Schema
    module Magnetic
      # Helps organizing the structure of the circuit and allows to define steps that
      # might be inserted in a completely different order, but it's experimental.
      #
      # Translates linear DSL calls that might refer to the same task several times into a linear "drawing instruction"
      # that can be consumed by Schema.bla.
      #
      # This class is experimental.
      class Dependencies
        def initialize
          @groups  = {
            start:      Sequence.new,
            main:       Sequence.new, # normal steps
            end:        Sequence.new, # ends
            unresolved: Sequence.new, # div
          }

          @order = [ :start, :main, :end, :unresolved ]
        end

        def add(id, seq_options, group: :main, **sequence_options)
          group = @groups[group] or raise "unknown group #{group}, implement me"

          group.add(id, seq_options, **sequence_options) # handles
        end

        def to_a
          @order.collect{ |name| @groups[name].to_a }.flatten(1)
        end

        # private
        def find(id)
          @groups.find do |name, group|
            index = group.send( :find_index, id )
            return group, index if index
          end
        end
      end
    end # Magnetic
  end
end


# Activity.build do
#   step :extract,  failure: End("End.validate.extract_failed")
#   step :validate
# end
