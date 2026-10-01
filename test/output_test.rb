require "test_helper"

class OutputTest < Minitest::Spec
  it "exposes {#to_h}" do
    my_output = Trailblazer::Activity::Output.new(Object, :success)

    assert_equal my_output.to_h, {:signal=>Object, :semantic=>:success}
  end
end
