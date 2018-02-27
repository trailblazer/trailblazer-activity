module Trailblazer
  module Activity::Magnetic
    module DSL
      # Every DSL method creates a set of polarizations that are evaluated and decide about a task's
      # incoming and outgoing connections.
      #
      # @note The API of Polarization might be simplified soon.
      # @api  private
      class Polarization
        def initialize( output:raise, color:raise )
          @output, @color = output, color
        end

        def call(magnetic_to, plus_poles, options)
          [
            magnetic_to,
            plus_poles.merge( @output => @color ) # this usually adds a new Output to the task.
          ]
        end
      end # Polarization
    end
  end
end
