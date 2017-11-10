require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  class G; end
  class I; end
  class J; end


  it do
    activity = Activity.build do
      def Task
        ->(*) { snippet }
      end

      # task Task(), id: :inquiry_create, Left => :suspend_for_correct
      #   task Task(), id: :suspend_for_correct, Right => :inquiry_create
      # task Task(), id: :notify_pickup
      # task Task(), id: :suspend_for_pickup

      # task Task(), id: :pickup
      # task Task(), id: :suspend_for_process_id

      task G, id: :receive_process_id, Output(Right, :success) => :success
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Right, :success) => :success, Output(Left, :failure) => "report_invalid_result"# do

                                                  # means: :success => "report_invalid_result"-End.invalid_result"
        task J, id: "report_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result), magnetic_to: "process_result-Trailblazer::Circuit::Right"
      #end

      # task Task(), id: :notify_clerk
    end
  end
end


