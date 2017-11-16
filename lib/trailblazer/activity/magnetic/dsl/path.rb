module Trailblazer
  module Activity::Magnetic
    module DSL
      # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
      # Implements #task
      module Path
        def self.initialize_sequence(track_color: :success, end_semantic: :success, **)
          [
            # add Start
            [:add, ["Start.default", [ [], Circuit::Start.new(:default),
              [ Activity::Magnetic::PlusPole.new(Activity::Magnetic::Output(Circuit::Right, :success), track_color) ] ], group: :start ]],

            # add Path End (only one)
            [:add, ["End.#{track_color}", [ [track_color], Activity::Magnetic.End(track_color, end_semantic), [] ], group: :end]],
          ]
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
