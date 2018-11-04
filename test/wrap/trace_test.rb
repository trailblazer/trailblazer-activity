require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    nested = bc
    activity = Module.new do
      extend Activity::Path(name: :top)

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
    stack, signal, (options, flow_options), _ = Trailblazer::Activity::Trace.invoke( bc,
      [
        { content: "Let's start writing" },
        { flow: true }
      ]
    )

    signal.class.inspect.must_equal %{Trailblazer::Activity::End}
    options.inspect.must_equal %{{:content=>\"Let's start writing\"}}
    flow_options[:flow].inspect.must_equal %{true}

    output = Trailblazer::Activity::Trace::Present.(stack)

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity: {}>
    |-- Start.default
    |-- B
    |-- C
    `-- End.success}
  end

  it do
    stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { content: "Let's start writing" },
        {}
      ]
    )
# pp stack
    output = Trailblazer::Activity::Trace::Present.(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity: {top}>
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

  it "Present allows to inject :renderer and pass through additional arguments to the renderer" do
    stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { content: "Let's start writing" },
        {}
      ]
    )

    renderer = ->(level:, input:, name:, color:, **) { [level, %{#{level}/#{input.task}/#{name}/#{color}}] }

    output = Trailblazer::Activity::Trace::Present.(stack, renderer: renderer,
      color: "pink" # additional options.
    )

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- 1/#<Trailblazer::Activity: {top}>/#<Trailblazer::Activity: {top}>/pink
    |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |-- 2/#<Proc:.rb:4 (lambda)>/A/pink
    |-- 2/#<Trailblazer::Activity: {}>/<Nested>/pink
    |   |-- 3/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |   |-- 3/#<Proc:.rb:5 (lambda)>/B/pink
    |   |-- 3/#<Proc:.rb:6 (lambda)>/C/pink
    |   `-- 3/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
    |-- 2/#<Proc:.rb:7 (lambda)>/D/pink
    `-- 2/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end

  it "allows to inject custom :stack" do
    skip "this test goes to the developer gem"
    stack = Trailblazer::Activity::Trace::Stack.new

    begin
    returned_stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { content: "Let's start writing" },
        { stack: stack }
      ]
    )
  rescue
    # pp stack
        puts Trailblazer::Activity::Trace::Present.(stack)

  end

    returned_stack.must_equal stack
  end
end
