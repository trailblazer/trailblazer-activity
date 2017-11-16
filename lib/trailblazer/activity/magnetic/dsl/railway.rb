module Trailblazer
  module Activity::Magnetic
    module DSL
      module Railway
        def self.initialize_sequence(sequence, track_color: :success, failure_color: :failure, **)
          # add Path End (only one)
          sequence.add( "End.#{failure_color}", [ [failure_color], Activity::Magnetic.End(failure_color, :failure), [] ], group: :end )
        end




        def self.step(task, track_color: :success, failure_color: :failure, plus_poles: raise, **, &block)
          magnetic_to, plus_poles = Path.task(task, track_color: track_color, plus_poles: plus_poles)

          [
            magnetic_to,
            plus_poles.reconnect( :failure => failure_color )
          ]
        end

        def self.pass(task, track_color: :success, failure_color: :failure, plus_poles: raise, **)
          magnetic_to, plus_poles = Railway.step(task, track_color: track_color, plus_poles: plus_poles)

          [
            magnetic_to,
            plus_poles.reconnect( :success => track_color, :failure => track_color) # :failure ==> :success
          ]
        end

        def self.fail(task, track_color: :success, failure_color: :failure, plus_poles: raise, **)
          magnetic_to, plus_poles = Railway.step(task, track_color: track_color, plus_poles: plus_poles)

          [
            [failure_color], # a fail task is magnetic to :failure
            plus_poles.reconnect( :success => failure_color, :failure => failure_color) # :failure ==> :failure, :success => :failure
          ]
        end
      end
    end
  end
end
