require "test_helper"

class ActivityTest < Minitest::Spec
  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  it do
    activity = Activity.build do
      # circular
      task A, id: "inquiry_create", Output(Left, :failure) => Path() do
        task B, id: "suspend_for_correct", Output(:success) => "inquiry_create"
      end

      task G, id: "receive_process_id"
      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_result) do
        task J, id: "report_invalid_result"
        task K, id: "log_invalid_result"
      end

      task L, id: :notify_clerk
    end

    activity.outputs.must_equal( {} )

    activity.()

    # activity.draft #=> mergeable, inheritance.
  end
end

