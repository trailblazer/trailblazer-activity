require "test_helper"

class ActivityTest < Minitest::Spec
  # TODO: :method invocation

  describe ":task_builder" do
    let(:activity) do
      activity = Module.new do
        extend Trailblazer::Activity::Path( task_builder: ->(task, *){task} )

        task T.def_task(:a)
        task T.def_task(:b), id: "b"
      end
    end

    it "doesn't wrap the task method with Task" do
      skip

      assert_path activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
}
    end
  end

  describe ":normalizer" do
    let(:activity) do
      my_simple_normalizer = ->(task, options){ [ task, { plus_poles: Trailblazer::Activity::Magnetic::PlusPoles.initial( :success => Trailblazer::Activity::Magnetic::Builder::Path.default_outputs[:success] ) }, {}, {}, {} ] }

      activity = Module.new do
        extend Trailblazer::Activity::Path( normalizer: my_simple_normalizer )

        task T.def_task(:a)
        task T.def_task(:b), id: "b"
      end
    end

    it "uses :normalizer instead of building one, and doesn't wrap the tasks with Task" do
      skip

      assert_path activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
}
    end
  end


  it "empty Activity" do
    skip
    activity = Module.new do
      extend Trailblazer::Activity::Path()
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

  end





  it "can start with any task" do
    skip
    signal, (options, _) = activity.( [{}], start_task: L )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:L=>1}}
  end

end

