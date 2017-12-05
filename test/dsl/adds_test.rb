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

    out.inspect.must_equal %{[[:add, ["A", [[:green], String, [#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:green>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::Builder::FastTrack::FailFast, semantic=:fail_fast>, color=:fail_fast>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::Builder::FastTrack::PassFast, semantic=:pass_fast>, color=:pass_fast>]], {:group=>:start}]]]}

# polarizations = Activity::Magnetic::Builder::Path.TaskPolarizations(builder_options)
# pp Activity::Magnetic::Builder.adds("Start", String, binary_plus_poles, polarizations, [], { fast_track: true }, { group: :start })

  end

  it "no options" do
    builder_options = { track_color: :green }

    polarizations = Activity::Magnetic::Builder::FastTrack.StepPolarizations(builder_options)
    PP.pp Activity::Magnetic::Builder.adds("A", String, binary_plus_poles, polarizations, [], { }, { group: :main }), dump = ""

    dump.must_equal %{[[:add,
  ["A",
   [[:green],
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
   [[:green],
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

  def start
    return %{#<Trailblazer::Circuit::Start: @name=:default, @options={}>} if RUBY_PLATFORM == "java"

    %{#<Trailblazer::Circuit::Start:
     @name=:default,
     @options={}>}
  end

  it "Path.InitialAdds" do
    PP.pp Activity::Magnetic::Builder::Path.InitialAdds(track_color: :green, end_semantic: :success), dump =""

    dump.gsub(/0x\w+/, "").must_equal %{[[:add,
  ["Start.default",
   [[],
    #{start},
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:green>]],
   {:group=>:start}]],
 [:add,
  ["End.green",
   [[:green],
    #<Trailblazer::Circuit::End:
     @name=:green,
     @options={:semantic=>:success}>,
    []],
   {:group=>:end}]]]
}
  end

  it "Railway.InitialAdds" do
    PP.pp Activity::Magnetic::Builder::Railway.InitialAdds(failure_color: :failure, track_color: :green, end_semantic: :success), dump =""

    dump.gsub(/0x\w+/, "").must_equal %{[[:add,
  ["Start.default",
   [[],
    #{start},
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:green>]],
   {:group=>:start}]],
 [:add,
  ["End.green",
   [[:green],
    #<Trailblazer::Circuit::End:
     @name=:green,
     @options={:semantic=>:success}>,
    []],
   {:group=>:end}]],
 [:add,
  ["End.failure",
   [[:failure],
    #<Trailblazer::Circuit::End:
     @name=:failure,
     @options={:semantic=>:failure}>,
    []],
   {:group=>:end}]]]
}
  end

  it "FastTrack.InitialAdds" do
    PP.pp Activity::Magnetic::Builder::FastTrack.InitialAdds(failure_color: :failure, track_color: :green, end_semantic: :success), dump =""

    dump.gsub(/0x\w+/, "").must_equal %{[[:add,
  ["Start.default",
   [[],
    #{start},
    [#<struct Trailblazer::Activity::Magnetic::PlusPole
      output=
       #<struct Trailblazer::Activity::Magnetic::Output
        signal=Trailblazer::Circuit::Right,
        semantic=:success>,
      color=:green>]],
   {:group=>:start}]],
 [:add,
  ["End.green",
   [[:green],
    #<Trailblazer::Circuit::End:
     @name=:green,
     @options={:semantic=>:success}>,
    []],
   {:group=>:end}]],
 [:add,
  ["End.failure",
   [[:failure],
    #<Trailblazer::Circuit::End:
     @name=:failure,
     @options={:semantic=>:failure}>,
    []],
   {:group=>:end}]],
 [:add,
  ["End.pass_fast",
   [[:pass_fast],
    #<Trailblazer::Circuit::End:
     @name="pass_fast",
     @options={:semantic=>:pass_fast}>,
    []],
   {:group=>:end}]],
 [:add,
  ["End.fail_fast",
   [[:fail_fast],
    #<Trailblazer::Circuit::End:
     @name="fail_fast",
     @options={:semantic=>:fail_fast}>,
    []],
   {:group=>:end}]]]
}
  end

# task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)

# task J, id: "extract",    magnetic_to: :success,
#                           Output(:success) => :success,
#                         Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)



  #task :    [:success], :success=>:success
  #step :    [:success], :success=>:success, :failure=>:failure
  #ff   :                                                   , :fail_fast=>:fail_fast, :pass_fast=>:pass_fast
  #ff (alt):                               , :failure=>:fail_fast
  #tuples  :             :exception=>:failure/"new-end"
  #tuples  :             :good     =>"good-end"
end


