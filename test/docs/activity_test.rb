require "test_helper"

require "test_helper"

# TODO: 3-level nesting test.

class CallTest < Minitest::Spec
  Circuit  = Trailblazer::Circuit
  Activity = Trailblazer::Activity

  module Blog
    Read    = ->((options, *args), *)   { options["Read"] = 1; [ Circuit::Right, [options, *args] ] }
    Next    = ->((options, *args), *) { options["NextPage"] = []; [ options["return"], [options, *args] ] }
    Comment = ->((options, *args), *)   { options["Comment"] = 2; [ Circuit::Right, [options, *args] ] }
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

      [direction, _options].must_equal [ blog.outputs.keys.first, [{"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]}, {}] ]

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]})
    end

    it "ends on comment" do
      direction, _options = blog.( [ options = { "return" => Circuit::Left } ] )

      [direction, _options].must_equal([blog.outputs.keys.first, [{"return"=>Trailblazer::Circuit::Left, "Read"=>1, "NextPage"=>[], "Comment"=>2} ] ])

      options.must_equal({"return"=> Circuit::Left, "Read"=> 1, "NextPage"=>[], "Comment"=>2})
    end
  end

  #- Circuit::End()
  describe "two End events" do
    Blog::Test = ->((options), *) { [ options[:return], [options] ] }

    let(:flow) do
      Activity.from_hash { |start, _end|
        {
          start      => { Circuit::Right => Blog::Test },
          Blog::Test => { Circuit::Right => _end, Circuit::Left => Circuit::End(:retry) }
        }
      }

      Activity.build do
        task Blog::Test, Left => Circuit::End(:retry)
      end
    end

    it { flow.([ { return: Circuit::Right }, {} ]).must_equal [flow.outputs.keys.first, [ {:return=>Trailblazer::Circuit::Right} ] ] }
    it { flow.([ { return: Circuit::Left },  {} ]).must_equal  [flow.outputs.keys.last,  [ {:return=>Trailblazer::Circuit::Left}  ] ] }
  end

  describe "arbitrary args for Circuit#call are passed and returned" do
    Plus    = ->((options, flow_options, a, b), *)      { [ Circuit::Right, [options, flow_options, a + b, 1] ] }
    PlusOne = ->((options, flow_options, ab_sum, i), *) { [ Circuit::Right, [options, flow_options, ab_sum.to_s, i+1] ] }

    let(:flow) do
      Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => Plus },
          Plus        => { Circuit::Right => PlusOne },
          PlusOne     => { Circuit::Right => _end },
        }
      }
    end

    it { flow.( [ {}, {a:"B"}, 1, 2 ] ).must_equal [ flow.outputs.keys.first, [ {}, {a:"B"}, "3", 2 ] ] }
  end

  describe "multiple Start events" do
    let(:alternative_start) { ->(args, *) { [ "custom signal", args ] } }

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
        [ :connect!, source: "Blog::Comment", target: activity.outputs.keys[0], edge: [ Circuit::Right, {} ] ],
      ]

      extended = Trailblazer::Activity.merge(activity, wirings)
    end

    it "runs from default start" do
      signal, ( options, * ) = blog.( [ options={}, {} ] )

      signal.must_equal blog.outputs.keys[0]
      options.must_equal( {"Read"=>1} )
    end

    it "starts from :start_event" do
      signal, ( options, * ) = blog.( [ options={}, {} ], start_event: alternative_start )

      signal.must_equal blog.outputs.keys[0]
      options.must_equal( {"Comment"=>2} )
    end
  end
end

# decouple circuit and implementation
# visible structuring of flow


class DocsActivityTest < Minitest::Spec
  class SpellChecker
    def self.error_count(string)
      string.scan("d").size
    end
  end

  #:write
  module Blog
    Circuit = Trailblazer::Circuit

    Write = ->((options, *flow), *) do
      options[:content] = options[:content].strip
      [ Circuit::Right, [options, *flow] ]
    end
    #:write end
    #:spell
    SpellCheck = ->((options, *flow), *) do
      direction = SpellChecker.error_count(options[:content]) ? Circuit::Right : Circuit::Left
      [ Circuit::Right, [options, *flow] ]
    end
    #:spell end
    Correct    = ->((options, *flow), *) { options[:content].sub!("d", "t"); [Circuit::Right, [options, *flow] ] }
    Publish    = ->((options, *flow), *) { [Circuit::Right, [options, *flow] ] }
  end
  #:impl1 end

  it do
    #:basic
    activity = Activity.from_hash do |start, _end|
      {
        start            => { Trailblazer::Circuit::Right => Blog::Write },
        Blog::Write      => { Trailblazer::Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Trailblazer::Circuit::Right => Blog::Publish,
                              Trailblazer::Circuit::Left => Blog::Correct },
        Blog::Correct    => { Trailblazer::Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Trailblazer::Circuit::Right => _end }
      }
    end
    #:basic end

    # Activity.from_hash

    #:call
    direction, options, flow = activity.(
      [
        { content: "Let's start writing   " } # gets trimmed in Write.
      ]
    )
    #:call end
    #:call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start writing"}
    #:call-ret end

    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal([{:content=>"Let's start writing"}])

    # ---
    #- tracing

    #:trace-act
    activity = Activity.from_hash do |start, _end|
      {
        start            => { Circuit::Right => Blog::Write },
        Blog::Write      => { Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
        Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Circuit::Right => _end }
      }
    end
    #:trace-act end

    #:trace-call
    stack, _ = Trailblazer::Activity::Trace.( activity,
      [
        { content: "Let's start writing" }
      ]
    )
    #:trace-call end

    puts Trailblazer::Activity::Trace::Present.tree(stack)
=begin
  #:trace-res
  puts Trailblazer::Activity::Trace::Present.tree(stack)
   |--> #<Start: default {}>{:content=>"Let's start writing"}
   |--> Blog::Write{:content=>"Let's start writing"}
   |--> Blog::SpellCheck{:content=>"Let's start writing"}
   |--> Blog::Publish{:content=>"Let's start writing"}
   `--> #<End: default {}>{:content=>"Let's start writing"}
  #:trace-res end
=end
  end

  # tolerate
  it do
    #:toll-spell
    Blog::SpellCheck3 = ->((options, *flow), *) do
      error_count = SpellChecker.error_count(options[:content])
      direction =
        if error_count <= 2 && error_count > 0
          :maybe
        elsif error_count > 2
          Circuit::Left
        else
          Circuit::Right
        end

      [ direction, [options, *flow] ]
    end
    #:toll-spell end
    Blog::Warn = ->((options, *flow), *) { options[:warning] = "Make less mistakes!"; [Circuit::Right, [options, *flow]] }

    #:toll
    activity = Activity.from_hash do |start, _end|
      {
        start       => { Circuit::Right => Blog::Write },
        Blog::Write       => { Circuit::Right => Blog::SpellCheck3 },
        Blog::SpellCheck3 => {
          Circuit::Right  => Blog::Publish,
          Circuit::Left   => Blog::Correct,
          :maybe          => Blog::Warn
        },
        Blog::Warn        => { Circuit::Right => Blog::Publish },
        Blog::Correct     => { Circuit::Right => Blog::SpellCheck3 },
        Blog::Publish     => { Circuit::Right => _end }
      }
    end
    #:toll end

    #:toll-call
    direction, options, flow = activity.(
      [ { content: " Let's start  " } ]
    )
    #:toll-call end
    #:toll-call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start"}
    #:toll-call-ret end

    # no errors
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal( [ {:content=>"Let's start"} ] )

    # 1 error
    direction, (options, flow) = activity.(
      [ { content: " Let's sdart" } ]
    )
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})

    # 3 error
    direction, (options, flow) = activity.(
      [ { content: " Led's sdard" } ]
    )
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's sdard", :warning=>"Make less mistakes!"})



    #---
    #- events
    #:events
    warn    = Circuit::End.new(:warned)
    wrong   = Circuit::End.new(:wrong)
    default = Circuit::End.new(:published)

    activity = Activity.from_hash(default) do |start, _end|
      {
        start       => { Circuit::Right => Blog::Write },
        Blog::Write       => { Circuit::Right => Blog::SpellCheck3 },
        Blog::SpellCheck3 => {
          Circuit::Right  => Blog::Publish,
          Circuit::Left   => wrong,
          :maybe          => Blog::Warn
        },
        Blog::Warn        => { Circuit::Right => warn },
        # Blog::Correct     => { Circuit::Right => Blog::SpellCheck3 },
        Blog::Publish     => { Circuit::Right => _end }
      }
    end
    #:events end

    # 1 error
    #:events-call
    direction, options, flow = activity.(
      [ { content: " Let's sdart" } ]
    )

    direction #=> #<End: warned {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:events-call end

    direction.must_inspect_end_fixme "#<End: warned {}>"
    options.must_equal( [ {:content=>"Let's sdart", :warning=>"Make less mistakes!"} ] )

    # ---
    # Subprocess
    Shop = ->(*args) { [ Circuit::Right, *args] }
    #:nested
    complete = Activity.from_hash(default) do |start, _end|
      {
        start => { Circuit::Right => Shop },
        Shop        => { Circuit::Right => activity },
        activity    => {
          default   => _end, # connect published to our End.
          wrong     => error = Circuit::End.new(:error),
          warn      => error
        }
      }
    end
    #:nested end

    #:nested-call
    direction, (options, flow) = complete.(
      [ { content: " Let's sdart" } ]
    )

    direction #=> #<End: error {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:nested-call end

    direction.must_inspect_end_fixme "#<End: error {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})
  end
end
