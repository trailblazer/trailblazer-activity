require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    nested = bc
    activity = Module.new do
      extend Activity[]
      include Activity::TaskWrap

      task task: A, id: "A"
      task task: nested, nested.outputs[:success] => :success, id: "<Nested>"
      task task: D, id: "D"
    end
    activity
  end

  let(:bc) do
    activity = Module.new do
      extend Activity[]
      include Activity::TaskWrap

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

    output.must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- B
|-- C
`-- #<Trailblazer::Activity::End:>}
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

    output.must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- A
|-- <Nested>
|   |-- #<Trailblazer::Activity::Start:>
|   |-- B
|   |-- C
|   `-- #<Trailblazer::Activity::End:>
|-- D
`-- #<Trailblazer::Activity::End:>}
  end
end
