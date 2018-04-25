require "test_helper"

class TaskWrapMacroTest < Minitest::Spec
  TaskWrap = Trailblazer::Activity::TaskWrap
  Builder  = Trailblazer::Activity::Magnetic::Builder

  # Sample {Extension}
  # We test if we can change `activity` here.
  SampleExtension = ->(activity, task, local_options, connections, sequence_options, **kws) do
    # save all args somewhere readable.
    activity[:args_from_extension] = [activity, task, local_options.keys, connections.inspect, sequence_options]
    activity[:args_from_extension_2] = [kws.keys, kws[:original_dsl_args][0], kws[:original_dsl_args][1].keys.inspect, kws[:original_dsl_args][2], kws[:original_dsl_args][3] ]

    # add another task via the :extension API.
    activity.task task: T.def_task(:b), id: "add_another_1", before: local_options[:id]
  end


  Block = ->(*) { snippet }
  #
  # Actual {Activity} using :extension
  module Create
    extend Trailblazer::Activity::Path()

    task task: A = T.def_task(:a), extension: [ SampleExtension ], id: "a", Output(nil, :failure) => End(:special), group: :main, &Block
  end

  it "runs two tasks" do
    event, (options, flow_options) = Create.( [{ seq: [] }, {}], {} )

    options.must_equal( {:seq=>[:b, :a]} )
  end

  describe "add_introspection" do
    let(:rvm_string) { %{[[#<Method: #<Trailblazer::Activity: {TaskWrapMacroTest::Create}>.a>, {:id=>\"a\"}], [#<Method: #<Trailblazer::Activity: {TaskWrapMacroTest::Create}>.b>, {:id=>\"add_another_1\"}]]} }
    it { skip; Create.debug.to_h.sort_by{ |a,b| a.inspect  }.inspect.must_equal rvm_string }
  end

  it "passes through all options" do
    Create[:args_from_extension].must_equal [Create, Create::A, [:plus_poles, :task, :extension, :id],
      "{#<struct Trailblazer::Activity::Output signal=nil, semantic=:failure>=>#<Trailblazer::Activity::End semantic=:special>}",
      {:group=>:main},

    ]
    Create[:args_from_extension_2].must_equal [[:original_dsl_args], :task, "[:task, :extension, :id, #<struct Trailblazer::Activity::Output signal=nil, semantic=:failure>, :group]", {}, Block]
  end
end
