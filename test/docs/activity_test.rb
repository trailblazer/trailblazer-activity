require "test_helper"

class DocsActivityTest < Minitest::Spec
  it do
    #:int
    Intermediate = Trailblazer::Activity::Intermediate # shortcut alias.

    intermediate = Intermediate.new(
      {
        Intermediate::TaskRef(:"Start")  => [Intermediate::Out(:success, :A)],
        Intermediate::TaskRef(:A)        => [Intermediate::Out(:success, :B),
                                             Intermediate::Out(:failure, :C)],
        Intermediate::TaskRef(:B)        => [Intermediate::Out(:success, "End.success")],
        Intermediate::TaskRef(:C)        => [Intermediate::Out(:success, :B)],
        Intermediate::TaskRef(:"End", stop_event: true) => [Intermediate::Out(:success, nil)]
      },
      [:"End"],   # end events
      [:"Start"], # start
    )
    #:int end

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        []),
      :C => Schema::Implementation::Task(c = C, [Activity::Output(Activity::Right, :success)],                                        []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end
end
