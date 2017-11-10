require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right





  it do
    activity = Activity.build do
      A = ->(*) { snippet }
      B = ->(*) { snippet }
      C = ->(*) { snippet }
      D = ->(*) { snippet }
      E = ->(*) { snippet }
      F = ->(*) { snippet }
      G = ->(*) { snippet }
      H = ->(*) { snippet }
      I = ->(*) { snippet }
      J = ->(*) { snippet }
      K = ->(*) { snippet }

      # task A, id: :inquiry_create, Left => :suspend_for_correct
      #   task B, id: :suspend_for_correct, Right => :inquiry_create
      # task C, id: :notify_pickup
      # task D, id: :suspend_for_pickup

      # task E, id: :pickup
      # task F, id: :suspend_for_process_id

      # task G, id: :receive_process_id
      # task H, id: :suspend_wait_for_result

      # task I, id: :process_result, Left => :report_invalid_result


        #task J, id: :report_invalid_result, Right => End("End.invalid_result", :invalid_result)
        task J, id: :report_invalid_result, Output(Left, :failure) => End("End.invalid_result", :invalid_result)

      task K, id: :notify_clerk
    end
  end
end


