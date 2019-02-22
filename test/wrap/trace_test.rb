require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    intermediate = Inter.new(
      {
        Inter::TaskRef(:B) => [Inter::Out(:success, :c)],
        Inter::TaskRef(:C) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success")],
      [Inter::TaskRef(:B)] # start
    )

    implementation = {
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: b, merge: TaskWrap.method(:initial_wrap_static))]),
      :C => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: c, merge: TaskWrap.method(:initial_wrap_static))]),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], [TaskWrap::Extension.new(task: _es, merge: TaskWrap.method(:initial_wrap_static))]), # DISCUSS: End has one Output, signal is itself?
    }

    # schema = Inter.(intermediate, implementation)


  end

  let(:bc) do
     intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B) => [Inter::Out(:success, :C)],
        Inter::TaskRef(:C) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success")],
      [Inter::TaskRef("Start.default")], # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        [TaskWrap::Extension.new(task: st, merge: TaskWrap.method(:initial_wrap_static))]),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: b, merge: TaskWrap.method(:initial_wrap_static))]),
      :C => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: c, merge: TaskWrap.method(:initial_wrap_static))]),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], [TaskWrap::Extension.new(task: _es, merge: TaskWrap.method(:initial_wrap_static))]), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  it do
    activity.({})
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

  it do
    stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { seq: [] },
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
