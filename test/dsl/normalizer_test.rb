require "test_helper"

class NormalizerTest < Minitest::Spec
  describe "DefaultNormalizer" do
    it "only knows sequence_options and default_options" do
      normalizer, _ = Trailblazer::Activity::Magnetic::DefaultNormalizer.build( some: "defaults", plus_poles: "default_plus_poles" )

      task, locals, dsl, sequence_options = normalizer.( "aTask", id: "A", Activity::DSL::Helper.Output(:success) => "find", before: "B" )

      task.must_equal "aTask"
      locals.inspect.must_equal %{{:plus_poles=>\"default_plus_poles\", :extension=>[], :id=>\"A\", #<struct Trailblazer::Activity::DSL::OutputSemantic value=:success>=>\"find\"}}
      dsl.inspect.must_equal %{{}}
      sequence_options.inspect.must_equal %{{:before=>\"B\"}}
    end
  end

  describe "Normalizer" do
    it do
      task = T.def_task(:a)

      normalizer, _ = Trailblazer::Activity::Magnetic::Normalizer.build( task_builder: ->(task) { task } )

      task, locals, connections, sequence_options, extension_options = normalizer.(
        {
          task: task,
          id: "A",
          Activity::DSL::Extension.new("callable extension") => true
        },
        {}
      )

      task.must_equal task
      locals[:id].must_equal "A"
      sequence_options.must_equal({})
      connections.must_equal({})
      extension_options.inspect.must_equal %{{#<struct Trailblazer::Activity::DSL::Extension callable=\"callable extension\">=>true, #<struct Trailblazer::Activity::DSL::Extension callable=#<Method: Trailblazer::Activity::DSL.record>>=>true}}
    end
  end
end
