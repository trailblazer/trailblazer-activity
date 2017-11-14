module Trailblazer
  module Activity::DSL
    # strategy.( task, track_color:, plus_poles:, pass_fast:, )
    module PoleGenerator
      # ONLY JOB: magnetic_to and Outputs ("Polarization")
      # Decorates #task
      class Railway
        def self.initialize_sequence(sequence, track_color: :success, failure_color: :failure, **)
          # add Path End (only one)
          sequence.add( "End.#{failure_color}", [ [failure_color], Circuit::End.new(:failure), [] ], group: :end )
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

      module FastTrack
        def self.initialize_sequence(sequence, *)
          sequence.add( "End.fail_fast", [ [:fail_fast], Circuit::End.new(:fail_fast), [] ], group: :end )
          sequence.add( "End.pass_fast", [ [:pass_fast], Circuit::End.new(:pass_fast), [] ], group: :end )
        end




        # todo: remove the signals in Operation.
        FailFast = Class.new
        PassFast = Class.new

        def self.step(task, **options)
          magnetic_to, plus_poles = Railway.step(task, options)

          plus_poles = plus_poles.reconnect( :success   => :pass_fast ) if options[:pass_fast]
          plus_poles = plus_poles.reconnect( :failure   => :fail_fast ) if options[:fail_fast]
          plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

          [
            magnetic_to,
            plus_poles
          ]
        end

        def self.fail(task, **options)
          magnetic_to, plus_poles = Railway.fail(task, options)

          plus_poles = plus_poles.reconnect( :failure => :fail_fast, :success => :fail_fast ) if options[:fail_fast]
          plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

          [
            magnetic_to,
            plus_poles
          ]
        end

        def self.pass(task, **options)
          magnetic_to, plus_poles = Railway.pass(task, options)

          plus_poles = plus_poles.reconnect( :success => :pass_fast, :success => :pass_fast ) if options[:pass_fast]
          plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

          [
            magnetic_to,
            plus_poles
          ]
        end
      end

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
    end # PoleGenerator
  end
end

# initial_plus_poles = Right => :success, Left => :failure

=begin

Path
  (Right, :success) => :success
Railway
  (Right, :success) => :success
  (Left,  :failure) => :failure
          (Right, :success) => :success
          (Left,  :failure) => :success
PassFast
          (Right, :success) => :pass_fast
          (Left,  :failure) => :pass_fast

FastTrack
  (Right,    :success)   => :success
  (Left,     :failure)   => :failure
  (PassFast, :pass_fast) => :pass_fast
  (FailFast, :fail_fast) => :fail_fast

=end
