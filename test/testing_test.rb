require "test_helper"

class TestingTest < Minitest::Spec
  extend T.def_steps(:model)

  klass = Class.new do
    def self.persist
    end
  end

  it "what" do
    assert_equal T.render_task(TestingTest.method(:model)), %{#<Method: TestingTest.model>}
    assert_equal T.render_task(:model), %{model}
    assert_equal T.render_task(klass.method(:persist)), %{#<Method: #<Class:0x>.persist>}
  end
end
