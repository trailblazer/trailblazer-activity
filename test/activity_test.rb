require "test_helper"

class ActivityTest < Minitest::Spec
  describe ":task_builder" do
    let(:activity) do
      activity = Module.new do
        extend Trailblazer::Activity::Path( task_builder: ->(task, *){task} )

        task T.def_task(:a)
        task T.def_task(:b), id: "b"
      end
    end

    it "doesn't wrap the task method with Task" do
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

    it do
      signal, (ctx, _) = activity.( [{seq: []}, {}] )
      ctx.inspect.must_equal %{{:seq=>[:a, :b]}}
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
      assert_path activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
}
    end

    it do
      signal, (ctx, _) = activity.( [{seq: []}, {}] )
      ctx.inspect.must_equal %{{:seq=>[:a, :b]}}
    end
  end


  class A
    def self.call((options, flow_options), *)
      options[:A] = 1

      [ options[:a_return], options, flow_options ]
    end
  end
  class B < Activity::End
    def call((options, flow_options), *)
      options[:B] = 1
      super
    end
  end
  class C
    def self.call((options, flow_options), *)
      options[:C] = 1

      [ options[:c_return], options, flow_options ]
    end
  end
  class D
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class G
    def self.call((options, flow_options), *)
      options[:G] = 1

      [ options[:g_return], options, flow_options ]
    end
  end
  class I
    def self.call((options, flow_options), *)
      options[:I] = 1

      [ options[:i_return], options, flow_options ]
    end
  end
  class J
    def self.call((options, flow_options), *)
      options[:J] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end
  class K
    def self.call((options, flow_options), *)
      options[:K] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end
  class L
    def self.call((options, flow_options), *)
      options[:L] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end

  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  it "empty Activity" do
    activity = Module.new do
      extend Trailblazer::Activity::Path()
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    Outputs(activity.outputs).must_equal %{success=> (#<Trailblazer::Activity::End semantic=:success>, success)}

    options = { id: 1 }

    signal, args, circuit_options = activity.( [options, {}], {} )

    signal.must_equal activity.outputs[:success].signal
    args.inspect.must_equal %{[{:id=>1}, {}]}
    circuit_options.must_be_nil
  end

  describe "unconnected ends" do
    it "are valid outputs since they define the interface" do
      activity = Module.new do
        extend Trailblazer::Activity::Path()

        _end task: End(:invalid)
      end

      activity.outputs.inspect.must_equal %{{:invalid=>#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=:invalid>, semantic=:invalid>, :success=>#<struct Trailblazer::Activity::Output signal=#<Trailblazer::Activity::End semantic=:success>, semantic=:success>}}
    end
  end

  let(:activity) do
    activity = Module.new do
      extend Trailblazer::Activity::Path( name: "Test::Create", task_builder: ->(task, *){task} )

      # circular
      task A, id: "inquiry_create", Output(Left, :failure) => Path() do
        _end B.new(semantic: :resume_1), id: "resume_for_correct"
        task C, id: "suspend_for_correct", Output(:success) => "inquiry_create", Output(:failure) => "inquiry_create"
      end

      task G, id: "receive_process_id"
      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_result) do
        task J, id: "report_invalid_result"
        task K
      end

      task L, id: :notify_clerk
    end
  end

  it do
    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Left} => #<ActivityTest::B/:resume_1>
 {Trailblazer::Activity::Right} => ActivityTest::G
#<ActivityTest::B/:resume_1>

ActivityTest::C
 {Trailblazer::Activity::Right} => ActivityTest::A
 {Trailblazer::Activity::Left} => ActivityTest::A
ActivityTest::G
 {Trailblazer::Activity::Right} => ActivityTest::I
 {Trailblazer::Activity::Left} => ActivityTest::I
ActivityTest::I
 {Trailblazer::Activity::Left} => ActivityTest::J
 {Trailblazer::Activity::Right} => ActivityTest::L
ActivityTest::J
 {Trailblazer::Activity::Right} => ActivityTest::K
 {Trailblazer::Activity::Left} => ActivityTest::K
ActivityTest::K
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
 {Trailblazer::Activity::Left} => #<End/:invalid_result>
ActivityTest::L
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>

#<End/"track_0.">

#<End/:invalid_result>
}


    Ends(activity.to_h[:circuit]).must_equal %{[#<ActivityTest::B/:resume_1>,#<End/:success>,#<End/\"track_0.\">,#<End/:invalid_result>]}

    # A -> B -> End.suspend
    options, flow_options, circuit_options = {id: 1, a_return: Activity::Left, b_return: Activity::Right }, {}, {}
    # ::call
    signal, (options, _) = activity.( [options, flow_options], circuit_options )

    signal.must_equal activity.outputs[:resume_1].signal
    options.inspect.must_equal %{{:id=>1, :a_return=>Trailblazer::Activity::Left, :b_return=>Trailblazer::Activity::Right, :A=>1, :B=>1}}

    #---
    #- start from C, stop in B
    options = { c_return: Activity::Right, a_return: Activity::Left }
    signal, (options, _) = activity.( [options, flow_options], start_task: C )

    signal.must_equal activity.outputs[:resume_1].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Left, :C=>1, :A=>1, :B=>1}}

    #---
    #- start from C, via G>I>L
    options = { c_return: Activity::Right, a_return: Activity::Right, g_return: Activity::Right, i_return: Activity::Right }
    signal, (options, _) = activity.( [options, flow_options], start_task: C )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Right, :g_return=>Trailblazer::Activity::Right, :i_return=>Trailblazer::Activity::Right, :C=>1, :A=>1, :G=>1, :I=>1, :L=>1}}

    #---
    #- start from C, via G>I>J>K
    options = { c_return: Activity::Right, a_return: Activity::Right, g_return: Activity::Right, i_return: Activity::Left }
    signal, (options, _) = activity.( [options, flow_options], start_task: C )

    signal.must_equal activity.outputs[:invalid_result].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Right, :g_return=>Trailblazer::Activity::Right, :i_return=>Trailblazer::Activity::Left, :C=>1, :A=>1, :G=>1, :I=>1, :J=>1, :K=>1}}

    # activity.draft #=> mergeable, inheritance.
  end

  describe "::task with macro style" do
    it "accepts sequence_options" do
      activity = Module.new do
        extend Trailblazer::Activity::Path()

        task task: A, id: "a"
        task task: B, before: "a", id: "b"
      end

      assert_path activity, %{
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => ActivityTest::A
 {Trailblazer::Activity::Left} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
}
    end
  end

  describe "#inspect" do
    it "shows name of anonymous module" do
      activity = Module.new do
        extend Trailblazer::Activity::Path( name: "Test::Create" )
        task T.def_task(:a)
      end

      activity.inspect.must_equal %{#<Trailblazer::Activity: {Test::Create}>}
    end
  end

  it "can start with any task" do
    signal, (options, _) = activity.( [{}], start_task: L )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:L=>1}}
  end

  describe "internal state" do
    it "a blank Activity exposes frozen objects, only" do
      activity = Module.new do
        extend Trailblazer::Activity::Path()
      end

      components = activity.to_h

      assert components[:process]

      assert components[:circuit].frozen?
      assert components[:outputs].frozen?
      assert components[:adds].frozen?
      assert components[:builder].frozen?
    end

    it "exposes frozen objects, only" do
      activity = Module.new do
        extend Trailblazer::Activity::Path()
        task A
      end

      components = activity.to_h

      assert components[:circuit].frozen?
      assert components[:outputs].frozen?
      assert components[:adds].frozen?
      assert components[:builder].frozen?
      # TODO: test @options.frozen?
    end
  end

  describe "inheritance" do
    it "creates a fresh Activity" do
      skip
      activity = Class.new(Activity) do
        task A
        task B
      end

      subactivity = Class.new(activity) do
        task C
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

      Cct(subactivity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => ActivityTest::C
ActivityTest::C
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end
end

