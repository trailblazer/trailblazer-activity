require "test_helper"

class ActivityTest < Minitest::Spec
  it "provides {#inspect}" do
    Trailblazer::Activity.new({}).inspect.gsub(/0x\w+/, "0x").must_equal %{#<Trailblazer::Activity:0x>}
  end

  it "empty Activity" do
    skip
    activity = Module.new do
      extend Trailblazer::Activity::Path()
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "can start with any task" do
    skip
    signal, (options, _) = activity.( [{}], start_task: L )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:L=>1}}
  end

# TODO: test {to_h} properly
  it "exposes {:data} attributes in {#to_h}" do
    bc.to_h[:nodes][1][:data].inspect.must_equal %{{:additional=>true}}
  end
end
