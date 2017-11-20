require "test_helper"

class ActivityTest < Minitest::Spec
  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

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
    circuit_options.must_equal nil
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

    Outputs(activity.outputs).must_equal %{{#<Trailblazer::Circuit::End: @name=:success, @options={:semantic=>:success}>=>:success}}


    puts Cct(activity.instance_variable_get(:@process))
    activity.instance_variable_get(:@process).must_equal ""


    Ends(activity.instance_variable_get(:@process)).must_equal %{}

    activity.()

    # activity.draft #=> mergeable, inheritance.
  end

  def Outputs(outputs)
    outputs.inspect.gsub(/0x\w+/, "")
  end
end

