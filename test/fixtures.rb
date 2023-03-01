module Fixtures
  Activity  = Trailblazer::Activity
  Inter     = Trailblazer::Activity::Schema::Intermediate
  Schema    = Trailblazer::Activity::Schema
  TaskWrap  = Trailblazer::Activity::TaskWrap

  module Implementing
    extend Activity::Testing.def_tasks(:a, :b, :c, :d, :f, :g)

    Start = Activity::Start.new(semantic: :default)
    Failure = Activity::End(:failure)
    Success = Activity::End(:success)
  end

  def flat_activity(implementing: Implementing)
    return @_flat_activity if defined?(@_flat_activity)

    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default")      => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B, additional: true) => [Inter::Out(:success, :C), Inter::Out(:failure, "End.failure")],
        Inter::TaskRef(:C)                   => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true, semantic: :success) => [],
        Inter::TaskRef("End.failure", stop_event: true, semantic: :failure) => [],
      },
      {
        "End.success" => :success,
        "End.failure" => :failure,
      },
      "Start.default", # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = Implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success), Activity::Output(Activity::Left, :failure)],                  []),
      :C => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  []),
      "End.success" => Schema::Implementation::Task(Implementing::Success, [], []), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(Implementing::Failure, [], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter::Compiler.(intermediate, implementation)

    @_flat_activity = Activity.new(schema)
  end

  def nested_activity(flat_activity: bc, d_id: :D)
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B, more: true)  => [Inter::Out(:success, d_id)],
        Inter::TaskRef(d_id) => [Inter::Out(:success, :E)],
        Inter::TaskRef(:E) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true, semantic: :success) => []
      },
      {"End.success" => :success},
      "Start.default" # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = Implementing::Start, [Activity::Output(Activity::Right, :success)], []),
      :B => Schema::Implementation::Task(b = Implementing.method(:b), [Activity::Output(Activity::Right, :success)], []),
      d_id => Schema::Implementation::Task(flat_activity, [Activity::Output(Implementing::Success, :success)], []),
      :E => Schema::Implementation::Task(e = Implementing.method(:f), [Activity::Output(Activity::Right, :success)], []),
      "End.success" => Schema::Implementation::Task(Implementing::Success, [], []),
    }

    schema = Inter::Compiler.(intermediate, implementation)

    Activity.new(schema)
  end

  alias_method :bc, :flat_activity
  alias_method :bde, :nested_activity
end
