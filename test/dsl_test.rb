require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right





  it do
    activity = Activity.build do
      def Task
        ->(*) { snippet }
      end

      task Task(), id: :inquiry_create, Left => :suspend_for_correct
        task Task(), id: :suspend_for_correct, Right => :inquiry_create
      task Task(), id: :notify_pickup
      task Task(), id: :suspend_for_pickup

      task Task(), id: :pickup
      task Task(), id: :suspend_for_process_id

      task Task(), id: :receive_process_id
      task Task(), id: :suspend_wait_for_result

      task Task(), id: :process_result, Left => :report_invalid_result
        task Task(), id: :report_invalid_result, Right => End("End.invalid_result", :invalid_result)

      task Task(), id: :notify_clerk
    end
  end
end


