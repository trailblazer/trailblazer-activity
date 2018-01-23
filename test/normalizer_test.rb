require "test_helper"

class NormalizerTest < Minitest::Spec
  it do
    task = T.def_task(:a)

    normalizer, _ = Trailblazer::Activity::Magnetic::Normalizer.build( task_builder: ->(task) { task } )

    task, locals, dsl, sequence_options = normalizer.({task: task, id: "A"}, {})

    task.must_equal task
    locals[:id].must_equal "A"
    sequence_options.must_equal({})
  end
end
