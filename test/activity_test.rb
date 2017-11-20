require "test_helper"

class ActivityTest < Minitest::Spec
  class A
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class B
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class C
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class D
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class G
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class I
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class J
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class K
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class L
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end

  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  it "empty Activity" do
    activity = Activity.build do
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>
}

    Outputs(activity.outputs).must_equal %{{#<Trailblazer::Circuit::End: @name=:success, @options={:semantic=>:success}>=>:success}}

    options = { id: 1 }

    signal, args, circuit_options = activity.( [options, {}], {} )

    Outputs(signal).must_equal %{#<Trailblazer::Circuit::End: @name=:success, @options={:semantic=>:success}>}
    args.inspect.must_equal %{[{:id=>1}, {}]}
    circuit_options.must_be_nil
  end

  it do
    activity = Activity.build do
      # circular
      task A, id: "inquiry_create", Output(Left, :failure) => Path() do
        task B, id: "suspend_for_correct", Output(:success) => "inquiry_create"
      end

      task G, id: "receive_process_id"
      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_result) do
        task J, id: "report_invalid_result"
        task K
      end

      task L, id: :notify_clerk
    end

    Cct(activity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Circuit::Left} => ActivityTest::B
 {Trailblazer::Circuit::Right} => ActivityTest::G
ActivityTest::B
 {Trailblazer::Circuit::Right} => ActivityTest::A
ActivityTest::G
 {Trailblazer::Circuit::Right} => ActivityTest::I
ActivityTest::I
 {Trailblazer::Circuit::Left} => ActivityTest::J
 {Trailblazer::Circuit::Right} => ActivityTest::L
ActivityTest::J
 {Trailblazer::Circuit::Right} => ActivityTest::K
ActivityTest::K
 {Trailblazer::Circuit::Right} => #<End:track_0./:invalid_result>
ActivityTest::L
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:success>

#<End:track_0./:invalid_result>
}

    Outputs(activity.outputs).must_equal %{{#<Trailblazer::Circuit::End: @name=:success, @options={:semantic=>:success}>=>:success, #<Trailblazer::Circuit::End: @name=\"track_0.\", @options={:semantic=>:invalid_result}>=>:invalid_result}}

    Ends(activity.instance_variable_get(:@process)).must_equal %{[#<End:success/:success>,#<End:track_0./:invalid_result>]}

    options, flow_options, circuit_options = {id: 1}, {}, {}
    # ::call
    signal, args = activity.( [options, flow_options], circuit_options )

    # activity.draft #=> mergeable, inheritance.
  end

  def Outputs(outputs)
    outputs.inspect.gsub(/0x\w+/, "").gsub(/\d\d+/, "")
  end
end

