require "test_helper"

require "trailblazer/activity/magnetic"

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


  it do
    builder_options = { track_color: :green }

    # path = Activity::Magnetic::Builder::Path.new(builder_options)

    polarizations = Activity::Magnetic::Builder::FastTrack.StepPolarizations(builder_options)
    out = pp Activity::Magnetic::Builder.adds("A", String, binary_plus_poles, polarizations, [], { fast_track: true }, { group: :start })

    out.inspect.must_equal %{[[:add, ["A", [:green, String, [#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:green>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::Builder::FastTrack::FailFast, semantic=:fail_fast>, color=:fail_fast>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::Builder::FastTrack::PassFast, semantic=:pass_fast>, color=:pass_fast>]], {:group=>:start}]]]}

# polarizations = Activity::Magnetic::Builder::Path.TaskPolarizations(builder_options)
# pp Activity::Magnetic::Builder.adds("Start", String, binary_plus_poles, polarizations, [], { fast_track: true }, { group: :start })

  end

  it "no options" do
    builder_options = { track_color: :green }

    polarizations = Activity::Magnetic::Builder::FastTrack.StepPolarizations(builder_options)
    PP.pp Activity::Magnetic::Builder.adds("A", String, binary_plus_poles, polarizations, [], { }, { group: :main }), dump = ""

    dump.must_equal %{[[:add,
  ["A",
   [:green,
    String,
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:green>,
     #<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Left,
        semantic=:failure>,
      color=:failure>]],
   {:group=>:main}]]]
}
  end

    it "options: :pass_fast => true" do
    builder_options = { track_color: :green }

    polarizations = Activity::Magnetic::Builder::FastTrack.StepPolarizations(builder_options)
    PP.pp Activity::Magnetic::Builder.adds("A", String, binary_plus_poles, polarizations, [], { pass_fast: true }, { group: :main }), dump = ""

    dump.must_equal %{[[:add,
  ["A",
   [:green,
    String,
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:pass_fast>,
     #<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Left,
        semantic=:failure>,
      color=:failure>]],
   {:group=>:main}]]]
}
  end

  it "Path.InitialAdds" do
    PP.pp Activity::Magnetic::Builder::Path.InitialAdds(track_color: :green, end_semantic: :success), dump =""

    dump.gsub(/0x\w+/, "").must_equal %{[[:add,
  ["Start.default",
   [[],
    #<Trailblazer::Circuit::Start:
     @name=:default,
     @options={}>,
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:green>]],
   {:group=>:start}]],
 [:add,
  ["End.green",
   [:green,
    #<Trailblazer::Circuit::End:
     @name=:green,
     @options={:semantic=>:success}>,
    []],
   {:group=>:end}]]]
}
  end


# task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)

# task J, id: "extract",    magnetic_to: :success,
#                           Output(:success) => :success,
#                         Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)


  module Polarization
    # Called once per DSL method call, e.g. ::step.
    #
    # The idea is to chain a bunch of PlusPoles transformations (and magnetic_to "transformations")
    # for each DSL call, and thus realize things like path+railway+fast_track
    def self.apply(polarizations, magnetic_to, plus_poles, options)
      polarizations.inject([magnetic_to, plus_poles]) do |args, pol|
        magnetic, plus_poles = pol.(*args, options)
      end
    end
  end








  #task :    [:success], :success=>:success
  #step :    [:success], :success=>:success, :failure=>:failure
  #ff   :                                                   , :fail_fast=>:fail_fast, :pass_fast=>:pass_fast
  #ff (alt):                               , :failure=>:fail_fast
  #tuples  :             :exception=>:failure/"new-end"
  #tuples  :             :good     =>"good-end"
  def self.Apply(id, task, magnetic_to, plus_poles, polarizations, options, sequence_options)
    magnetic_to, plus_poles = Polarization.apply(polarizations, magnetic_to, plus_poles, options)


  # def self.AddsForTask(task, id:, magnetic_to:, plus_poles:, sequence_options:, **)
    add = [ :add, [id, [ magnetic_to, task, plus_poles.to_a ], sequence_options] ]

    [ add ]
  end

  # for all "dsl user options":
  dsl_polarizations = Activity::Magnetic::DSL::ProcessOptions.("a", { Activity::Magnetic.Output("Signal", :success3) => :failure, Activity::Magnetic.Output("Signal2", :success2) => :failure } , binary_plus_poles )

# for one task:
polarizations =
  [
    Activity::Magnetic::Builder::Path::TaskPolarization.new( track_color: :green ), # comes from ::task
  ]

polarizations += dsl_polarizations


  pp Apply("a", String, nil, binary_plus_poles, polarizations, { fast_track: true }, { group: :main })


puts



  #---




end


