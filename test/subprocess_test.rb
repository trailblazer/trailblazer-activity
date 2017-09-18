require "test_helper"

class SubprocessHelper < Minitest::Spec
  Circuit = Trailblazer::Circuit
  Activity = Trailblazer::Activity

  module Blog
    Read    = ->(direction, options, *)    { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = []; [ options["return"], options ] }
    Comment = ->(direction, options, *)    { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  module User
    Relax   = ->(direction, options, *) { options["Relax"]=true; [ Circuit::Right, options ] }
  end

  ### Subprocess( )
  ###
  describe "circuit with 1 level of nesting" do
    let(:blog) do
     Trailblazer::Activity.from_hash { |start, _end|
        {
          start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => _end, Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => _end }
        }
      }
    end

    let(:user) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => nested=blog  },
          nested     => { blog.end_events.first => User::Relax },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "ends before comment, on next_page" do
      user.(nil, options = { "return" => Circuit::Right }).must_equal([user.end_events.first, {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}, nil])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end
  end

  ### Subprocess( End1, End2 )
  ###
  describe "circuit with 2 end events in the nested process" do
    let(:blog) do
      _retry = Circuit::End.new(:retry)
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => _end, Circuit::Left => _retry },
        }
      }
    end

    let(:user) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => blog },
          blog     => { blog.end_events.first => User::Relax, blog.end_events[1] => _end },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "runs from Subprocess->default to Relax" do
      user.(nil, options = { "return" => Circuit::Right }).must_equal([user.end_events.first, {"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}, nil])

      options.must_equal({"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end

    it "runs from other Subprocess end" do
      user.(nil, options = { "return" => Circuit::Left }).must_equal([user.end_events.first, {"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]}, nil])

      options.must_equal({"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]})
    end

    #---
    #- Subprocess( activity, start_at )
    let(:with_nested_and_start_at) do
      Trailblazer::Activity.from_hash { |start, _end|
        {
          start => { Circuit::Right => nested=Activity::Subprocess(  blog, start_at: Blog::Next ) },
          nested     => { blog.end_events.first => User::Relax },

          User::Relax => { Circuit::Right => _end }
        }
      }
    end

    it "runs Subprocess from alternative start" do
      with_nested_and_start_at.(nil, options = { "return" => Circuit::Right }).
        must_equal( [with_nested_and_start_at.end_events.first, {"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true}, nil] )

      options.must_equal({"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true})
    end

    #---
    #- Subprocess(  activity ) { ... }
    describe "Subprocess with block" do
      let(:process) do
        class Workout
          def self.__call__(direction, options, flow_options)
            options[:workout]   = 9

            [ direction, options, flow_options ]
          end
        end

        nested = Activity::Subprocess(  Workout, start_at: "no start_at needed" ) do |activity:nil, start_at:nil, args:nil|
          activity.__call__(start_at, *args)
        end

        Trailblazer::Activity.from_hash { |start, _end|
          {
            start => { Circuit::Right => nested },
            nested     => { "no start_at needed" => User::Relax },

            User::Relax => { Circuit::Right => _end }
          }
        }
      end

      it "runs Subprocess from alternative start" do
        process.(nil, options = { "return" => Circuit::Right }).
          must_equal( [process.end_events.first, {"return"=>Circuit::Right, :workout=>9, "Relax"=>true}, nil] )

        options.must_equal({"return"=>Circuit::Right, :workout=>9, "Relax"=>true})
      end
    end


    #---
    #- Subprocess(  activity, call: :__call__ ) { ... }
    describe "Subprocess with :call option" do
      let(:process) do
        class Workout
          def self.__call__(direction, options, flow_options)
            options[:workout]   = 9

            [ direction=Circuit::Right, options, flow_options ]
          end
        end

        nested = Activity::Subprocess( Workout, call: :__call__ )

        Trailblazer::Activity.from_hash { |start, _end|
          {
            start       => { Circuit::Right => nested },
            nested      => { Circuit::Right => User::Relax },

            User::Relax => { Circuit::Right => _end }
          }
        }
      end

      it "runs Subprocess process with __call__" do
        process.(nil, options = { "return" => Circuit::Right }).
          must_equal( [process.end_events.first, {"return"=>Circuit::Right, :workout=>9, "Relax"=>true}, nil] )

        options.must_equal({"return"=>Circuit::Right, :workout=>9, "Relax"=>true})
      end
    end
  end
end
