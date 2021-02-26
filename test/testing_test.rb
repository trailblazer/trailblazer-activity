require "test_helper"

class TestingTest < Minitest::Spec
  extend T.def_steps(:model)

  klass = Class.new do
    def self.persist
    end
  end


  it "what" do
    _(T.render_task(TestingTest.method(:model))).must_equal %{#<Method: TestingTest.model>}
    _(T.render_task(:model)).must_equal %{model}
    _(T.render_task(klass.method(:persist))).must_equal %{#<Method: #<Class:0x>.persist>}
  end
end
