require "test_helper"

# TODO: 3-level nesting test.

class CallTest < Minitest::Spec
	Circuit  = Trailblazer::Circuit
  Activity = Trailblazer::Activity

  module Blog
    Read    = ->((options, *args))   { options["Read"] = 1; [ Circuit::Right, [options, *args] ] }
    Next    = ->((options, *args)) { options["NextPage"] = []; [ options["return"], [options, *args] ] }
    Comment = ->((options, *args))   { options["Comment"] = 2; [ Circuit::Right, [options, *args] ] }
  end

  describe "plain circuit without any nesting" do
    let(:blog) do
      Activity.from_hash { |start, _end|
        {
          start      => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => _end, Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => _end }
        }
      }
    end

    it "ends before comment, on next_page" do
      direction, _options = blog.( [ options = { "return" => Circuit::Right }, {} ] )

      [direction, _options].must_equal([ blog.end_events.first, [{"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]}, {}] ])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]})
    end

    it "ends on comment" do
      direction, _options = blog.([options = { "return" => Circuit::Left }, {}])
      [direction, _options].must_equal([blog.end_events.first, [{"return"=>Trailblazer::Circuit::Left, "Read"=>1, "NextPage"=>[], "Comment"=>2}, {}] ])

      options.must_equal({"return"=> Circuit::Left, "Read"=> 1, "NextPage"=>[], "Comment"=>2})
    end
  end

  #- Circuit::End()
  describe "two End events" do
    Blog::Test = ->((options)) { [ options[:return], [options] ] }

    let(:flow) do
      Activity.from_hash { |start, _end|
        {
          start      => { Circuit::Right => Blog::Test },
          Blog::Test => { Circuit::Right => _end, Circuit::Left => Circuit::End(:retry) }
        }
      }
    end

    it { flow.([ { return: Circuit::Right }, {} ]).must_equal [flow.end_events.first, [ {:return=>Trailblazer::Circuit::Right} ] ] }
    it { flow.([ { return: Circuit::Left },  {} ]).must_equal  [flow.end_events.last,  [ {:return=>Trailblazer::Circuit::Left}  ] ] }
  end

  describe "arbitrary args for Circuit#call are passed and returned" do
    Plus    = ->((options, flow_options, a, b))      { [ Circuit::Right, [options, flow_options, a + b, 1] ] }
    PlusOne = ->((options, flow_options, ab_sum, i)) { [ Circuit::Right, [options, flow_options, ab_sum.to_s, i+1] ] }

    let(:flow) do
      Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => Plus },
          Plus        => { Circuit::Right => PlusOne },
          PlusOne     => { Circuit::Right => _end },
        }
      }
    end

    it { flow.( [ {}, {a:"B"}, 1, 2 ] ).must_equal [ flow.end_events.first, [ {}, {a:"B"}, "3", 2 ] ] }
  end

  describe "multiple Start events" do
    let(:alternative_start) { ->(args) { [ "custom signal", args ] } }

    let(:blog) do
      activity = Activity.from_hash { |start, _end|
        {
          start             => { Circuit::Right => Blog::Read },
          Blog::Read        => { Circuit::Right => _end },

          # alternative_start => { "custom signal" => Blog::Comment },
          # Blog::Comment     => { Circuit::Right => _end }
        }
      }

      wirings = [
        [ :insert_before!, "Start.default", node: [ alternative_start, id: "alternative_start" ], incoming: ->(edge) { false } ],
        [ :attach!, source: "alternative_start", target: [ Blog::Comment, id: "Blog::Comment" ], edge: [ "custom signal", {} ] ],
        [ :connect!, source: "Blog::Comment", target: activity.end_events[0], edge: [ Circuit::Right, {} ] ],
      ]

      extended = Trailblazer::Activity.merge(activity, wirings)
    end

    it "runs from default start" do
      signal, ( options, * ) = blog.( [ options={}, {} ] )

      signal.must_equal blog.end_events[0]
      options.must_equal( {"Read"=>1} )
    end

    it "starts from :start_event" do
      signal, ( options, * ) = blog.( [ options={}, {} ], start_event: alternative_start )

      signal.must_equal blog.end_events[0]
      options.must_equal( {"Comment"=>2} )
    end
  end
end

# decouple circuit and implementation
# visible structuring of flow
