# TODO: move me to Operation.
module Trailblazer
  module Activity::Magnetic
    class Builder
      class FastTrack < Builder

        def self.StepPolarizations(**options)
          [
            *Railway.StepPolarizations(options),
            StepPolarization.new(options)
          ]
        end

        class StepPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :success   => :pass_fast ) if options[:pass_fast]
            plus_poles = plus_poles.reconnect( :failure   => :fail_fast ) if options[:fail_fast]
            plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

            [
              magnetic_to,
              plus_poles
            ]
          end
        end






        def self.keywords
          [:fail_fast, :pass_fast, :fast_track, :type]
        end


        # Adds the End.fail_fast and End.pass_fast end to the Railway sequence.
        def self.InitialAdds(**builder_options)
          path_adds = Railway.InitialAdds(**builder_options)

          ends = [:fail_fast, :pass_fast].collect do |name|
            adds(
              "End.#{name}", Activity::Magnetic.End("#{name}", name),

              {}, # plus_poles
              Path::TaskPolarizations(builder_options.merge( type: :End )),
              [],

              {},
              { group: :end },
              [name]
            )
          end

          path_adds + ends
        end

        def self.initialize_sequence(*)
          [
            [ :add, [ "End.fail_fast", [ [:fail_fast], Activity::Magnetic.End(:fail_fast), [] ], group: :end] ],
            [ :add, [ "End.pass_fast", [ [:pass_fast], Activity::Magnetic.End(:pass_fast), [] ], group: :end] ],
          ]
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

          plus_poles = plus_poles.reconnect( :success => :pass_fast, :failure => :pass_fast ) if options[:pass_fast]
          plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

          [
            magnetic_to,
            plus_poles
          ]
        end
      end
    end
  end
end
