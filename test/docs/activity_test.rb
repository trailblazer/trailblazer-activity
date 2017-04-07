require "test_helper"

class DocsActivityTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class SpellChecker
    def self.error_count(string)
      string.scan("d").size
    end
  end

  #:write
  module Blog
    Write = ->(direction, options, *flow) do
      options[:content] = options[:content].strip
      [ Circuit::Right, options, *flow ]
    end
    #:write end
    #:spell
    SpellCheck = ->(direction, options, *flow) do
      direction = SpellChecker.error_count(options[:content]) ? Circuit::Right : Circuit::Left
      [ direction, options, *flow ]
    end
    #:spell end
    Correct    = ->(direction, options, *flow) { options[:content].sub!("d", "t"); [Circuit::Right, options, *flow] }
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
      { content: "Let's start writing   " } # gets trimmed in Write.
    )
    #:call end
    #:call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start writing"}
    #:call-ret end

    direction.inspect.must_equal "#<End: default {}>"
    options.must_equal({:content=>"Let's start writing"})

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
      { content: "Let's start writing" },
      runner: Trailblazer::Circuit::Trace.new, stack: stack
    )
    #:trace-call end

    Circuit::Trace::Present.tree(stack)
=begin
  #:trace-res
  Circuit::Trace::Present.tree(stack)
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
    Blog::SpellCheck3 = ->(direction, options, *flow) do
      error_count = SpellChecker.error_count(options[:content])
      direction =
        if error_count <= 2 && error_count > 0
          :maybe
        elsif error_count > 2
          Circuit::Left
        else
          Circuit::Right
        end

      [ direction, options, *flow ]
    end
    #:toll-spell end
    Blog::Warn = ->(direction, options, *flow) { options[:warning] = "Make less mistakes!"; [Circuit::Right, options, *flow] }

    #:toll
    activity = Circuit::Activity({id: "Blog/Publish"}) { |evt|
      {
        evt[:Start]       => { Circuit::Right => Blog::Write },
        Blog::Write       => { Circuit::Right => Blog::SpellCheck3 },
        Blog::SpellCheck3 => {
          Circuit::Right  => Blog::Publish,
          Circuit::Left   => Blog::Correct,
          :maybe          => Blog::Warn
        },
        Blog::Warn        => { Circuit::Right => Blog::Publish },
        Blog::Correct     => { Circuit::Right => Blog::SpellCheck3 },
        Blog::Publish     => { Circuit::Right => evt[:End] }
      }
    }
    #:toll end

    #:toll-call
    direction, options, flow = activity.(
      activity[:Start],
      { content: " Let's start  " }
    )
    #:toll-call end
    #:toll-call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start"}
    #:toll-call-ret end

    # no errors
    direction.inspect.must_equal "#<End: default {}>"
    options.must_equal({:content=>"Let's start"})

    # 1 error
    direction, options, flow = activity.(
      activity[:Start],
      { content: " Let's sdart" }
    )
    direction.inspect.must_equal "#<End: default {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})

    # 3 error
    direction, options, flow = activity.(
      activity[:Start],
      { content: " Led's sdard" }
    )
    direction.inspect.must_equal "#<End: default {}>"
    options.must_equal({:content=>"Let's sdard", :warning=>"Make less mistakes!"})



    #---
    #- events
    #:events
    activity = Circuit::Activity({id: "Blog/Publish"},
      end: {
        default: Circuit::End.new(:published),
        warn:    Circuit::End.new(:warned),
        wrong:   Circuit::End.new(:wrong)
      }
    ) { |evt|
      {
        evt[:Start]       => { Circuit::Right => Blog::Write },
        Blog::Write       => { Circuit::Right => Blog::SpellCheck3 },
        Blog::SpellCheck3 => {
          Circuit::Right  => Blog::Publish,
          Circuit::Left   => evt[:End, :wrong],
          :maybe          => Blog::Warn
        },
        Blog::Warn        => { Circuit::Right => evt[:End, :warn] },
        Blog::Correct     => { Circuit::Right => Blog::SpellCheck3 },
        Blog::Publish     => { Circuit::Right => evt[:End] }
      }
    }
    #:events end

    # 1 error
    #:events-call
    direction, options, flow = activity.(
      activity[:Start],
      { content: " Let's sdart" }
    )

    direction #=> #<End: warned {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:events-call end

    direction.inspect.must_equal "#<End: warned {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})

    # ---
    # Nested
    Shop = ->(*args) { args }
    #:nested
    complete = Circuit::Activity(
      {id: "Shop, Blog"},
      end: { default: Circuit::End.new(:default), error: Circuit::End.new(:error) }
    ) do |evt|
      {
        evt[:Start] => { Circuit::Right => Shop },
        Shop        => { Circuit::Right => _nested = Circuit::Nested(activity) },
        _nested     => {
          activity[:End, :default] => evt[:End], # connect published to our End.
          activity[:End, :wrong]   => evt[:End, :error],
          activity[:End, :warn]    => evt[:End, :error]
        }
      }
    end
    #:nested end

    #:nested-call
    direction, options, flow = complete.(
      complete[:Start],
      { content: " Let's sdart" }
    )

    direction #=> #<End: error {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:nested-call end

    direction.inspect.must_equal "#<End: error {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})
  end
end

