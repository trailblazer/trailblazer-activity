# TODO: move me to Operation.
module Trailblazer
  module Activity::Magnetic
    class Builder
      class FastTrack < Builder
        def initialize(normalizer, builder_options={})
          builder_options = { # Ruby's kw args kind a suck.
            track_color: :success, end_semantic: :success, failure_color: :failure,
          }.merge(builder_options) # FIXME: copied from Railway!!!!

          super

          add!(
            FastTrack.InitialAdds( builder_options )   # add start, success end and failure end, pass_fast and fail_fast.
          )
        end

        def self.StepPolarizations(**options)
          [
            *Railway.StepPolarizations(options),
            StepPolarization.new(options)
          ]
        end

        def self.FailPolarizations(**options)
          [
            *Railway.FailPolarizations(options),
            FailPolarization.new(options)
          ]
        end

        def self.PassPolarizations(**options)
          [
            *Railway.PassPolarizations(options),
            PassPolarization.new(options)
          ]
        end

        class StepPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :success   => :pass_fast ) if options[:pass_fast]
            plus_poles = plus_poles.reconnect( :failure   => :fail_fast ) if options[:fail_fast]

            plus_poles = plus_poles.merge(
              Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast,
              Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast
            ) if options[:fast_track]

            [
              magnetic_to,
              plus_poles
            ]
          end
        end

        class FailPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :failure => :fail_fast, :success => :fail_fast ) if options[:fail_fast]
            plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

            [
              magnetic_to,
              plus_poles
            ]
          end
        end

        class PassPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :success => :pass_fast, :failure => :pass_fast ) if options[:pass_fast]
            plus_poles = plus_poles.merge( Activity::Magnetic.Output(FailFast, :fail_fast) => :fail_fast, Activity::Magnetic.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

            [
              magnetic_to,
              plus_poles
            ]
          end
        end

        def self.DefaultNormalizer(*args)
          Railway.DefaultNormalizer(*args)
        end
        def self.DefaultPlusPoles(*args)
          Railway.DefaultPlusPoles(*args)
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

          path_adds + ends.flatten(1)
        end

        # todo: remove the signals in Operation.
        FailFast = Class.new
        PassFast = Class.new

        def step(task, options={}, &block)
          insert_element!( FastTrack.StepPolarizations(@builder_options), task, options, &block )
        end

        def fail(task, options={}, &block)
          insert_element!( FastTrack.FailPolarizations(@builder_options), task, options, &block )
        end

        def pass(task, options={}, &block)
          insert_element!( FastTrack.PassPolarizations(@builder_options), task, options, &block )
        end

        # FIXME: copied from Railway!
        def insert_element!(polarizations, task, options, &block)
          adds = FastTrack.adds_for(polarizations, @normalizer, task, options, &block)

          add!(adds)
        end
      end
    end
  end
end
