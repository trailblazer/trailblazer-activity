require "test_helper"

class DocsRailwayTest < Minitest::Spec
  module Methods
    def authenticate(ctx, **)

    end
    def auth_err(ctx, **)

    end
    def reset_counter(ctx, **)

    end
    def find_model(ctx, **)

    end
  end

  class ThirdTrackTest < Minitest::Spec
    Memo = Class.new(Memo)

    module Memo::Create
      extend Trailblazer::Activity::Railway()
      #~methods
      extend Methods
      #~methods end
      step method(:authenticate), Output(:failure) => :auth_failed
      step method(:auth_err),      magnetic_to: [:auth_failed], Output(:success) => :auth_failed
      step method(:reset_counter), magnetic_to: [:auth_failed], Output(:success) => End(:authentication_failure)

      step method(:find_model)
    end

    it do
       Cct(Memo::Create.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.authenticate>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.authenticate>}>
 {Trailblazer::Activity::Left} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.find_model>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:authentication_failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackTest::Memo::Create}>.find_model>}>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/:authentication_failure>
}
    end

  end

  class ThirdTrackWithPathTest < Minitest::Spec
    Memo = Class.new(Memo)

    module Memo::Create
      extend Trailblazer::Activity::Railway()
      #~methods
      extend Methods
      #~methods end
      step method(:authenticate), Output(:failure) => Path() do
        task Memo::Create.method(:auth_err)
        task Memo::Create.method(:reset_counter), Output(:success) => End(:authentication_failure)
      end

      step method(:find_model)
    end

    it do
       Cct(Memo::Create.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.authenticate>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.authenticate>}>
 {Trailblazer::Activity::Left} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.find_model>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:authentication_failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathTest::Memo::Create}>.find_model>}>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/\"track_0.\">

#<End/:authentication_failure>
}
    end

  end

  class ThirdTrackWithPathAndImplicitEndTest < Minitest::Spec
    Memo = Class.new(Memo)

    module Memo::Create
      extend Trailblazer::Activity::Railway()
      #~methods
      extend Methods
      #~methods end
      step method(:authenticate), Output(:failure) => Path( end_semantic: :authentication_failure) do
        task Memo::Create.method(:auth_err)
        task Memo::Create.method(:reset_counter)
      end

      step method(:find_model)
    end

    it do
       Cct(Memo::Create.to_h[:circuit], inspect_task: Activity::Introspect.method(:inspect_task_builder)).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.authenticate>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.authenticate>}>
 {Trailblazer::Activity::Left} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.find_model>}>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.auth_err>}>
 {Trailblazer::Activity::Right} => #<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.reset_counter>}>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:authentication_failure>
#<TaskBuilder{#<Method: #<Trailblazer::Activity: {DocsRailwayTest::ThirdTrackWithPathAndImplicitEndTest::Memo::Create}>.find_model>}>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>

#<End/:authentication_failure>
}
    end

  end

end


# So, the entire mental model of setting up a complex graph with a linear DSL is based on some super simple algorithm I came up with
# That assumes that very task has "magnetic" inputs, and magnetic outputs
# and that way, you can build more complex graphs super easily, once you get the hang of the "magnetic" model
