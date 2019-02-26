require "test_helper"

class TraceTest < Minitest::Spec
  it do
    nested_activity.([{seq: []}])
  end

  it "traces flat activity" do
    stack, signal, (options, flow_options), _ = Trailblazer::Activity::Trace.invoke( bc,
      [
        { seq: [] },
        { flow: true }
      ]
    )

    signal.class.inspect.must_equal %{Trailblazer::Activity::End}
    options.inspect.must_equal %{{:seq=>[:b, :c]}}
    flow_options[:flow].inspect.must_equal %{true}

    output = Trailblazer::Activity::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- C
    `-- End.success}
  end

  it "allows nested tracing" do
    stack, _ = Trailblazer::Activity::Trace.invoke( nested_activity,
      [
        { seq: [] },
        {}
      ]
    )

    output = Trailblazer::Activity::Trace::Present.(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- D
    |   |-- Start.default
    |   |-- B
    |   |-- C
    |   `-- End.success
    |-- E
    `-- End.success}
  end

  it "Present allows to inject :renderer and pass through additional arguments to the renderer" do
    stack, _ = Trailblazer::Activity::Trace.invoke( nested_activity,
      [
        { seq: [] },
        {}
      ]
    )

    renderer = ->(level:, input:, name:, color:, **) { [level, %{#{level}/#{input.task}/#{name}/#{color}}] }

    output = Trailblazer::Activity::Trace::Present.(stack, renderer: renderer,
      color: "pink" # additional options.
    )

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- 1/#<Trailblazer::Activity:>/#<Trailblazer::Activity:>/pink
    |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |-- 2/#<Method: #<Module:>.b>/B/pink
    |-- 2/#<Trailblazer::Activity:>/D/pink
    |   |-- 3/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |   |-- 3/#<Method: #<Module:>.b>/B/pink
    |   |-- 3/#<Method: #<Module:>.c>/C/pink
    |   `-- 3/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
    |-- 2/#<Method: #<Module:>.f>/E/pink
    `-- 2/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end

  it "allows to inject custom :stack" do
    skip "this test goes to the developer gem"
    stack = Trailblazer::Activity::Trace::Stack.new

    begin
    returned_stack, _ = Trailblazer::Activity::Trace.invoke( nested_activity,
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
