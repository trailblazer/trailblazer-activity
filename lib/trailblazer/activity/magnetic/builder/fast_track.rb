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

        # pass_fast: true simply means: color my :success Output with :pass_fast color
        class StepPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :success   => :pass_fast ) if options[:pass_fast]
            plus_poles = plus_poles.reconnect( :failure   => :fail_fast ) if options[:fail_fast]

            # add fast track outputs if :fast_track
            plus_poles = plus_poles.reverse_merge(
              Activity.Output(FailFast, :fail_fast) => :fail_fast,
              Activity.Output(PassFast, :pass_fast) => :pass_fast
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
            plus_poles = plus_poles.reverse_merge( Activity.Output(FailFast, :fail_fast) => :fail_fast, Activity.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

            [
              magnetic_to,
              plus_poles
            ]
          end
        end

        class PassPolarization < Railway::StepPolarization
          def call(magnetic_to, plus_poles, options)
            plus_poles = plus_poles.reconnect( :success => :pass_fast, :failure => :pass_fast ) if options[:pass_fast]
            plus_poles = plus_poles.reverse_merge( Activity.Output(FailFast, :fail_fast) => :fail_fast, Activity.Output(PassFast, :pass_fast) => :pass_fast ) if options[:fast_track]

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
          [:fail_fast, :pass_fast, :fast_track, :type, :override]
        end


        # Adds the End.fail_fast and End.pass_fast end to the Railway sequence.
        def self.InitialAdds(pass_fast_end: Activity.End("pass_fast", :pass_fast), fail_fast_end: Activity.End("fail_fast", :fail_fast), **builder_options)
          path_adds = Railway.InitialAdds(**builder_options)

          ends =
            adds(
              "End.pass_fast", pass_fast_end,

              {}, # plus_poles
              Path::TaskPolarizations(builder_options.merge( type: :End )),
              [],

              {},
              { group: :end },
              [:pass_fast]
            )+
            adds(
              "End.fail_fast", fail_fast_end,

              {}, # plus_poles
              Path::TaskPolarizations(builder_options.merge( type: :End )),
              [],

              {},
              { group: :end },
              [:fail_fast]
            )

          path_adds + ends
        end

        # Direction signals.
        FailFast = Class.new(Circuit::Signal)
        PassFast = Class.new(Circuit::Signal)

        def step(task, options={}, &block)
          insert_element!( FastTrack, FastTrack.StepPolarizations(@builder_options), task, options, &block )
        end

        def fail(task, options={}, &block)
          insert_element!( FastTrack, FastTrack.FailPolarizations(@builder_options), task, options, &block )
        end

        def pass(task, options={}, &block)
          insert_element!( FastTrack, FastTrack.PassPolarizations(@builder_options), task, options, &block )
        end
      end
    end
  end
end
