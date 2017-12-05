require "test_helper"

class IntrospectionTest < Minitest::Spec
  A = ->(*args) { [ Circuit::Right, *args ] }
  B = ->(*args) { [ Circuit::Right, *args ] }
  C = ->(*args) { [ Circuit::Right, *args ] }
  D = ->(*args) { [ Circuit::Right, *args ] }

  let(:activity) do
    nested = bc
    seq = Activity.build do
      task A
      task nested, Output(nested.outputs.keys.first, :success) => :success
      task D, id: "D"
    end
  end

  let(:bc) do
    Activity.build do
      task B
      task C
    end
  end

require "trailblazer/activity/magnetic/builder/introspection"
  it do
    puts Trailblazer::Activity::Magnetic::Builder::Introspection.cct( activity.instance_variable_get(:@builder) )
end
end
