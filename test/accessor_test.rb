require "test_helper"

class AccessorTest < Minitest::Spec
  let(:activity) do
    Module.new { extend Activity::Path() }
  end

  it "exposes reader and writer for 1 level" do
    activity[:name] = "Success"

    activity[:name].must_equal "Success"
  end

  it "for 2 level, it exposes accessors" do
    activity[:debug] = {}
    activity[:debug, :a] = "Success"
    activity[:debug, :a].must_equal "Success"
  end

  it "for 2 level, it automatically initializes 2nd key as a Hash" do
    activity[:debug, :a] = "Success"
    activity[:debug, :a].must_equal "Success"
  end

  it "returns nil when keys are absent" do
    activity[:unknown].must_be_nil
    activity[:unknown, :nonexistant].must_be_nil
  end
end
