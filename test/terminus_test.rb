require "test_helper"

class TerminusNodeTest < Minitest::Spec
  it "Success#call" do
    success = Trailblazer::Activity::Terminus::Success[semantic: :success]

    result = success.({params: {}}, {exec_context: Object}, nil, current_task: Module)
    assert_equal result, [
      {params: {}},
      {exec_context: Object},
      success # signal is the terminus instance itself.
    ]
  end

  it "Failure#call" do
    failure = Trailblazer::Activity::Terminus::Failure[semantic: :pass_fast]

    result = failure.({params: {}}, {exec_context: Object}, nil, current_task: Module)
    assert_equal result, [
      {params: {}},
      {exec_context: Object},
      failure # signal is the terminus instance itself.
    ]
  end

  it "{#initialize} takes any kwargs" do
    success = Trailblazer::Activity::Terminus::Success[semantic: :success, copy_from_outer_ctx: []]

    assert_equal success.to_h, {semantic: :success}
  end
end
