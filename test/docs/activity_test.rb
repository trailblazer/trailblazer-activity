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
    activity = Trailblazer::Activity.from_hash do |start, _end|
      {
        start            => { Circuit::Right => Blog::Write },
        Blog::Write      => { Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
        Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Circuit::Right => _end }
      }
    end
    #:basic end

    # Activity.from_hash

    #:call
    direction, options, flow = activity.(
      nil,
      { content: "Let's start writing   " } # gets trimmed in Write.
    )
    #:call end
    #:call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start writing"}
    #:call-ret end

    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's start writing"})

    # ---
    #- tracing

    #:trace-act
    activity = Trailblazer::Activity.from_hash do |start, _end|
      # Blog::Write=>"Blog::Write",Blog::SpellCheck=>"Blog::SpellCheck",Blog::Correct=>"Blog::Correct", Blog::Publish=>"Blog::Publish" }) { |evt|
      {
        start      => { Circuit::Right => Blog::Write },
        Blog::Write      => { Circuit::Right => Blog::SpellCheck },
        Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
        Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
        Blog::Publish    => { Circuit::Right => _end }
      }
    end
    #:trace-act end

    #:trace-call
    stack, _ = Circuit::Trace.( activity,
      nil,
      { content: "Let's start writing" }
    )
    #:trace-call end

    puts Circuit::Trace::Present.tree(stack)
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
    activity = Trailblazer::Activity.from_hash do |start, _end|
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
      nil,
      { content: " Let's start  " }
    )
    #:toll-call end
    #:toll-call-ret
    direction #=> #<End: default {}>
    options   #=> {:content=>"Let's start"}
    #:toll-call-ret end

    # no errors
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's start"})

    # 1 error
    direction, options, flow = activity.(
      nil,
      { content: " Let's sdart" }
    )
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})

    # 3 error
    direction, options, flow = activity.(
      nil,
      { content: " Led's sdard" }
    )
    direction.must_inspect_end_fixme "#<End: default {}>"
    options.must_equal({:content=>"Let's sdard", :warning=>"Make less mistakes!"})



    #---
    #- events
    #:events
    warn    = Circuit::End.new(:warned)
    wrong   = Circuit::End.new(:wrong)
    default = Circuit::End.new(:published)

    activity = Trailblazer::Activity.from_hash(default) do |start, _end|
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
      nil,
      { content: " Let's sdart" }
    )

    direction #=> #<End: warned {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:events-call end

    direction.must_inspect_end_fixme "#<End: warned {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})

    # ---
    # Nested
    Shop = ->(*args) { args }
    #:nested
    complete = Trailblazer::Activity.from_hash(default) do |start, _end|
      {
        start => { Circuit::Right => Shop },
        Shop        => { Circuit::Right => _nested = Circuit::Nested(activity) },
        _nested     => {
          default   => _end, # connect published to our End.
          wrong     => error = Circuit::End.new(:error),
          warn      => error
        }
      }
    end
    #:nested end

    #:nested-call
    direction, options, flow = complete.(
      nil,
      { content: " Let's sdart" }
    )

    direction #=> #<End: error {}>
    options   #=> {:content=>"Let's sdart", :warning=>"Make less mistakes!"}
    #:nested-call end

    direction.must_inspect_end_fixme "#<End: error {}>"
    options.must_equal({:content=>"Let's sdart", :warning=>"Make less mistakes!"})
  end
end

