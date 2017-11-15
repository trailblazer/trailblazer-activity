module Trailblazer
  module Activity::Magnetic
    module DSL
      # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
      # Implements #task
      module Path
        def self.initialize_sequence(sequence, track_color: :success, **)
          # add Start
          sequence.add( "Start.default", [ [], Circuit::Start.new(:default), [ Activity::Magnetic::PlusPole.new(Activity::Magnetic::Output(Circuit::Right, :success), track_color) ] ], group: :start )
          # add Path End (only one)
          sequence.add( "End.#{track_color}", [ [track_color], Circuit::End.new(track_color), [] ], group: :end )
        end





        def self.task(task, track_color: :success, plus_poles: raise, **, &block)
          [
            # magnetic_to:
            [track_color],
            # outputs:
            plus_poles.reconnect( :success => track_color )
          ]
        end
      end
    end
  end
end
