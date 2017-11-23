require "test_helper"

require "trailblazer/activity/magnetic"

module Trailblazer
  module Activity::Magnetic
    module DSL
      class Polarization
        def initialize( output:, color: )
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

class AddsTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Builder = Activity::Magnetic::Builder::Path

  binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

# task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)

# task J, id: "extract",    magnetic_to: :success,
#                           Output(:success) => :success,
#                         Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)


  module Polarization
    # Called once per DSL method call, e.g. ::step.
    def self.apply(polarizations, magnetic_to, plus_poles, options)
      polarizations.inject([magnetic_to, plus_poles]) do |args, pol|
        magnetic, plus_poles = pol.(*args, options)
      end
    end
  end


  module Task
    class Polarization
      def initialize( track_color: )
        @track_color = track_color
      end

      def call(magnetic_to, plus_poles, options)
        [
          magnetic_to || @track_color,
          plus_poles.reconnect( :success => @track_color )
        ]
      end
    end
  end



# for one task:
polarization_transformations =
  [
    Task::Polarization.new( track_color: :green ),

    Activity::Magnetic::DSL::Polarization.new(
      output: Activity::Magnetic.Output("exception", :exception),
      color:  :exception
    ),

  ]


  pp Polarization.apply(polarization_transformations, nil, binary_plus_poles, {})


  #task :    [:success], :success=>:success
  #step :    [:success], :success=>:success, :failure=>:failure
  #ff   :                                                   , :fail_fast=>:fail_fast, :pass_fast=>:pass_fast
  #ff (alt):                               , :failure=>:fail_fast
  #tuples  :             :exception=>:failure/"new-end"
  #tuples  :             :good     =>"good-end"
  def Apply(magnetic_to, plus_poles, dsl_tuples)

  end

  # task, id:, plus_poles, magnetic_to ===> ADDS
end


