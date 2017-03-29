require "test_helper"

class DocsActivityTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  #:write
  module Blog
    Write = ->(direction, options, *flow) do
      options[:content] = "World peace!"
      [ Circuit::Right, options, *flow ]
    end
    #:write end
    #:spell
    SpellCheck = ->(direction, options, *flow) do
      direction = options[:content].size > 10 ? Circuit::Right : Circuit::Left
      [ direction, options, *flow ]
    end
    #:spell end
    Correct    = ->(direction, options, *flow) { [Circuit::Right, options, *flow] }
    Publish    = ->(direction, options, *flow) { [Circuit::Right, options, *flow] }
  end
  #:impl1 end

  it do
    #:basic
    activity = Circuit::Activity({id: "Blog/Publish"}) { |evt|
      {
        evt[:Start]      => { Circuit::Right => Blog::Write },
        Blog::Write      => { Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
        Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Circuit::Right => evt[:End] }
      }
    }
    #:basic end

    #:call
    direction, options, flow = activity.(
      activity[:Start],
      { author: "Nick" }
    )
    #:call end
    #:call-ret
    direction #=> #<End: default {}>
    options   #=> {:author=>"Nick", :content=>"World peace!"}
    #:call-ret end

    direction.inspect.must_equal "#<End: default {}>"
    options.must_equal({:author=>"Nick", :content=>"World peace!"})

    # ---
    #- tracing

    #:trace-act
    require "trailblazer/circuit/present"

    activity = Circuit::Activity({id: "Blog/Publish",
      Blog::Write=>"Blog::Write",Blog::SpellCheck=>"Blog::SpellCheck",Blog::Correct=>"Blog::Correct", Blog::Publish=>"Blog::Publish" }) { |evt|
      {
        evt[:Start]      => { Circuit::Right => Blog::Write },
        Blog::Write      => { Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
        Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Circuit::Right => evt[:End] }
      }
    }
    #:trace-act end

    #:trace-call
    stack=[]

    direction, options, flow = activity.(
      activity[:Start],
      { author: "Nick" },
      runner: Trailblazer::Circuit::Trace.new, stack: stack
    )
    #:trace-call end

    Circuit::Trace::Present.tree(stack)
=begin
  #:trace-res
  Circuit::Trace::Present.tree(stack)
   |--> #<Start: default {}>{:author=>"Nick"}
   |--> Blog::Write{:author=>"Nick", :content=>"World peace!"}
   |--> Blog::SpellCheck{:author=>"Nick", :content=>"World peace!"}
   |--> Blog::Publish{:author=>"Nick", :content=>"World peace!"}
   `--> #<End: default {}>{:author=>"Nick", :content=>"World peace!"}
  #:trace-res end
=end
  end
end
