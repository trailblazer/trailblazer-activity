require "test_helper"

class PlusPolesTest < Minitest::Spec
  def test(description, &block)
    instance_exec(&block)
  end

  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  let(:poles) { Trailblazer::Activity::Magnetic::DSL::PlusPoles.new }

  # it do # TODO: delete me
  #   test "writes poles on brand-new instance" do
  #     poles = poles.merge(
  #       Activity.Output(Right, :success) => :success,
  #       Activity.Output(Left, :failure) => :failure
  #     )

  #     poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}
  #   end

  #   test "same-named semantic overwrites" do
  #     poles = poles.merge( Activity.Output("Right", :success) => :failure )
  #     poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"Right\", semantic=:success>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}
  #   end

  #   # overwrites the old :success Output
  #   overwritten = new_poles.merge( Activity.Output("Right", :success) => :failure )
  #   overwritten.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"Right\", semantic=:success>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}


  #   # add new output
  #   new_poles = new_poles.merge( Activity.Output("Another", :exception) => :fail_fast )

  #   new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"Another\", semantic=:exception>, color=:fail_fast>]}
  # end

  describe "#merge" do
    # it do # FIXME.
    #   require "simpletest"
    #   Simpletest.test "#merge" do
    #     poles = Trailblazer::Activity::Magnetic::DSL::PlusPoles.new
    #     let(:poles, poles)
    #     # let(:poles) { Trailblazer::Activity::Magnetic::DSL::PlusPoles.new }

    #     test "writes poles on brand-new instance" do |poles:|
    #       new_poles = poles.merge(
    #         Activity.Output(Right, :success) => :success,
    #         Activity.Output(Left, :failure)  => :failure
    #       )

    #       new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}
    #     end


    #   end
    # end

    it "writes poles on brand-new instance" do
      new_poles = poles.merge(
        Activity.Output(Right, :success) => :success,
        Activity.Output(Left, :failure)  => :failure
      )

      new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}
    end

    it "same-named semantic overwrites" do
      new_poles = poles.merge(
        Activity.Output(Right, :success) => :success,
        Activity.Output(Left, :failure)  => :failure
      )

      overwritten = new_poles.merge( Activity.Output("Right", :success) => :failure )
      overwritten.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"Right\", semantic=:success>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}
    end
  end

  describe "#reverse_merge" do
    it do
      # this could be auto-compiled by Nested:
      new_poles = poles.merge( Activity.Output("My.Right", :success) => :success, Activity.Output("My.Left", :failure) => :failure )
      # don't merge :success colored plus pole, because it's already there.
      new_poles = new_poles.reverse_merge( Activity.Output(Right, :something) => :success, Activity.Output("PassFast", :pass_fast) => :pass_fast )

      new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"My.Right\", semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"My.Left\", semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"PassFast\", semantic=:pass_fast>, color=:pass_fast>]}
    end
  end

  it "bug" do
    skip "how to suppress doubles?"
    new_poles = poles.merge( Activity.Output(Right, :success) => :success, Activity.Output(Left, :failure) => :failure )
    new_poles = new_poles.merge( Activity.Output("Signal", :pass_fast) => :success )

    new_poles.to_a.inspect.must_equal %{}
  end

  # overwrite existing
  it do
    new_poles = poles.merge( Activity.Output(Right, :success) => :success, Activity.Output(Left, :failure) => :failure )

    # reconnect
    new_poles = new_poles.reconnect(:success => :red)

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:red>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]}

    # reconnect with multiple keys
    new_poles = new_poles.reconnect(:success => :green, :failure => :greenish)

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:green>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:greenish>]}
  end

  describe "#reconnect" do
    it "skips not existing semantics" do
      poles = Trailblazer::Activity::Magnetic::DSL::PlusPoles.new
      new_poles = poles.merge( Activity.Output("My.Right", :success) => nil )

      new_poles = new_poles.reconnect( :success => :fantastic, :failure => :ignored )

      new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=\"My.Right\", semantic=:success>, color=:fantastic>]}
    end
  end

  describe "::from_outputs" do
    it "creates PlusPoles from an Activity's outputs" do
      activity = Activity.build do
        task :a
      end

      Activity::Magnetic::DSL::PlusPoles::from_outputs( activity.outputs ).to_a.inspect.gsub(/0x\w+/, "").inspect.
        must_equal %{"[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End: @name=:success, @options={:semantic=>:success}>, semantic=:success>, color=:success>]"}
    end
  end
end
