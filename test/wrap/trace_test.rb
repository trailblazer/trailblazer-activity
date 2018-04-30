require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    nested = bc
    activity = Module.new do
      extend Activity::Path()

      task task: A, id: "A"
      task task: nested, nested.outputs[:success] => Track(:success), id: "<Nested>"
      task task: D, id: "D"
    end
    activity
  end

  let(:bc) do
    activity = Module.new do
      extend Activity::Path()

      task task: B, id: "B"
      task task: C, id: "C"
    end
    activity
  end

  it do
    activity.({})
  end

  it "traces flat activity" do
    stack, signal, (options, flow_options), _ = Trailblazer::Activity::Trace.( bc,
      [
        { content: "Let's start writing" },
        { flow: true }
      ]
    )

    signal.class.inspect.must_equal %{Trailblazer::Activity::End}
    options.inspect.must_equal %{{:content=>\"Let's start writing\"}}
    flow_options[:flow].inspect.must_equal %{true}

    output = Trailblazer::Activity::Trace::Present.tree(stack)

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity: {}>
    |-- Start.default
    |-- B
    |-- C
    `-- End.success}
  end

  it do
    stack, _ = Trailblazer::Activity::Trace.( activity,
      [
        { content: "Let's start writing" },
        {}
      ]
    )
# pp stack
    output = Trailblazer::Activity::Trace::Present.tree(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity: {}>
    |-- Start.default
    |-- A
    |-- <Nested>
    |   |-- Start.default
    |   |-- B
    |   |-- C
    |   `-- End.success
    |-- D
    `-- End.success}
  end
end
