require 'test_helper'

# TODO: 3-level nesting test.

class CircuitTest < Minitest::Spec
	Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *)   { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = arg; [ options["return"], options ] }
    Comment = ->(direction, options, *)   { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  # let(:read)      { Circuit::Task(Blog::Read, "blog.read") }
  # let(:next_page) { Circuit::Task(Blog::NextPage, "blog.next") }
  # let(:comment)   { Circuit::Task(Blog::Comment, "blog.comment") }

  describe "plain circuit without any nesting" do
    let(:blog) do
      Circuit.new("blog.read/next") { |evt|
        {
          evt.Start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt.End, Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => evt.End }
        }
      }
    end

    it "ends before comment, on next_page" do
      blog.(Circuit.START, options = { "return" => Circuit::Right }).must_equal([blog.End, {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]}])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]})
    end

    it "ends on comment" do
      blog.(Circuit.START, options = { "return" => Circuit::Left }).must_equal([blog.End, {"return"=>Trailblazer::Circuit::Left, "Read"=>1, "NextPage"=>[], "Comment"=>2}])

      options.must_equal({"return"=> Circuit::Left, "Read"=> 1, "NextPage"=>[], "Comment"=>2})
    end
  end

  describe "two End events" do
    Blog::Test = ->(options) { [ options[:return], options ] }
    test = Circuit::Task(Blog::Test, "blog.test")

    let(:flow) do
      Circuit.new(:reading, end_events: {default: Circuit::End.new(:default), retry: Circuit::End.new(:retry)} ) { |evt|
        {
          evt.Start => { Circuit::Right => test },
          test      => { Circuit::Right => evt.End, Circuit::Left => evt.End(:retry) }
        }
      }

    end

    it { flow.(flow.Start, return: Circuit::Right).must_equal([flow.End,         {:return=>Trailblazer::Circuit::Right} ]) }
    it { flow.(flow.Start, return: Circuit::Left ).must_equal([flow.End(:retry), {:return=>Trailblazer::Circuit::Left} ]) }
  end

  # o->[ o->Blog::Read->O ]->Blog::NextPage->O
  # let(:flow) do
  #   nested=Circuit::Subprocess(Circuit::Nested(level1), "blog.reading")

  #   Circuit.new(:default) { |evt|
  #     {
  #       flow.Start => { Circuit::Right   => nested },
  #       nested         => { level1.STOP.to_id => next_page },
  #       next_page      => { Circuit::Right   => evt.STOP }
  #     }
  #   }
  # end


  # describe "Nested" do
  #   let(:level1) do
  #     Circuit.new(:reading) { |evt|
  #       {
  #         Circuit.START => { Circuit::Right => read },
  #         read           => { Circuit::Right => evt.STOP }
  #       }
  #     }
  #   end


  #   it "reaches NextPage after level1 STOPs" do
  #     flow.(Circuit.START, options = {}, "Argh!").must_equal(flow.STOP)

  #     options.must_equal({"Read"=>Circuit::Right, "NextPage"=>"Argh!"})
  #   end
  # end


=begin

  describe "with SUSPEND" do
    let(:reading) do
      Workflow.new(:reading) { |evt|
        {
          Workflow.START => { Workflow::Right => read },
          read           => { Workflow::Right => evt.SUSPEND },
          evt.RESUME     => { Workflow::Right => comment },
          comment        => { Workflow::Right => evt.STOP },
        }
      }
    end

    let(:default) do
      nested = Workflow::Subprocess(Workflow::Nested(reading), "blog.reading")

      Workflow.new(:default) { |evt|
      {
        Workflow.START => { Workflow::Right => nested },
        nested         => { reading.STOP.to_id => next_page, reading.SUSPEND.to_id => evt.Suspend(resume: reading.RESUME) }, # evt.SUSPEND will interrupt `default`.
        reading.RESUME => { Workflow::Right => Workflow::Subprocess(Workflow::Nested(reading, reading.RESUME), "blog.reading") },
        next_page      => { Workflow::Right => evt.STOP },
      }
    }
    end

    it "stops at reading.SUSPEND" do
      stop = default.(Workflow.START, options = {})

      stop.inspect.must_equal %{#<Suspend: default {:resume=>#<Resume: reading>}>}
      stop.to_resume.must_equal reading.RESUME

      options.must_equal({"Read"=>Trailblazer::Workflow::Right})
    end

    it "continues at reading.RESUME" do
      default.(reading.RESUME, options = {}, "Argh!!").must_equal default.STOP
      options.must_equal({"Comment"=>Trailblazer::Workflow::Right, "NextPage"=>"Argh!!"})
    end

    describe "with :suspend_event" do
      class MySuspend < Workflow::Suspend
        def call(last_activity, options)
          to_suspend("store me in session" => options.inspect)
        end
      end

      class NestedSuspend < Workflow::Suspend
        def call(last_activity, options)
          to_suspend(last_activity.to_session)
        end
      end

      let(:reading) do
        Workflow.new(:reading, suspend_event: MySuspend) { |evt|
          {
            Workflow.START => { Workflow::Right => read },
            read           => { Workflow::Right => evt.SUSPEND },
            evt.RESUME     => { Workflow::Right => comment },
            comment        => { Workflow::Right => evt.STOP },
          }
        }
      end

      let(:default) do
        nested = Workflow::Subprocess(Workflow::Nested(reading), "blog.Read")

        Workflow.new(:default, suspend_event: NestedSuspend) { |evt|
        {
          Workflow.START => { Workflow::Right => nested },
          nested         => { reading.STOP.to_id => next_page, reading.SUSPEND.to_id => evt.SUSPEND }, # evt.SUSPEND will interrupt `default`.
          reading.RESUME => { Workflow::Right => Workflow::Subprocess(Workflow::Nested(reading, reading.RESUME), "blog.Read") },
          next_page      => { Workflow::Right => evt.STOP },
        }
      }
      end

      # in flat workflow.
      it do
        stop = reading.(Workflow.START, options = {})
        stop.to_session.inspect.must_equal("{:resume=>#<Resume: reading>, \"store me in session\"=>\"{\\\"Read\\\"=>Trailblazer::Workflow::Right}\"}")
      end

      # in nested workflow.
      it do
        stop = default.(Workflow.START, options = {})

        stop.to_resume.to_id.must_equal "Trailblazer::Workflow::Resume.reading"

        # this can be used to serialize the session, e.g. in Sidekiq.
        session = stop.to_session
        session.inspect.must_equal("{:resume=>#<Resume: reading>, \"store me in session\"=>\"{\\\"Read\\\"=>Trailblazer::Workflow::Right}\"}")

        # RESUME
        stop = default.(reading.RESUME, options = {}.merge(session), "Argh!!!")
        options.inspect.must_equal("{:resume=>#<Resume: reading>, \"store me in session\"=>\"{\\\"Read\\\"=>Trailblazer::Workflow::Right}\", \"Comment\"=>Trailblazer::Workflow::Right, \"NextPage\"=>\"Argh!!!\"}")
        stop.to_id.must_equal("Trailblazer::Workflow::Stop.default")
      end
    end
  end
=end
end

# decouple circuit and implementation
# visible structuring of flow
