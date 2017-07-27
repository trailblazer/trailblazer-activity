require "test_helper"

class NestedHelper < Minitest::Spec
Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *)    { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = []; [ options["return"], options ] }
    Comment = ->(direction, options, *)    { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  module User
    Relax   = ->(direction, options, *) { options["Relax"]=true; [ Circuit::Right, options ] }
  end

  ### Nested()
  ###
  describe "circuit with 1 level of nesting" do
    let(:blog) do
      Circuit::Activity(id: "blog.read/next") { |evt|
        {
          evt[:Start]  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt[:End], Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => evt[:End] }
        }
      }
    end

    let(:user) do
      Circuit::Activity(id: "user.blog") { |user|
        {
          user[:Start] => { Circuit::Right => nested=Circuit::Nested(blog) },
          nested     => { blog[:End] => User::Relax },

          User::Relax => { Circuit::Right => user[:End] }
        }
      }
    end

    it "ends before comment, on next_page" do
      user.(user[:Start], options = { "return" => Circuit::Right }).must_equal([user[:End], {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}, nil])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end
  end

  ### Nested( End1, End2 )
  ###
  describe "circuit with 2 end events in the nested process" do
    let(:blog) do
      Circuit::Activity({ id: "blog.read/next" }, end: { default: Circuit::End.new(:default), retry: Circuit::End.new(:retry) } ) { |evt|
        {
          evt[:Start]  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt[:End], Circuit::Left => evt[:End, :retry] },
        }
      }
    end

    let(:user) do
      Circuit::Activity(id: "user.blog") { |user|
        {
          user[:Start] => { Circuit::Right => nested=Circuit::Nested(blog) },
          nested     => { blog[:End] => User::Relax, blog[:End, :retry] => user[:End] },

          User::Relax => { Circuit::Right => user[:End] }
        }
      }
    end

    it "runs from Nested->default to Relax" do
      user.(user[:Start], options = { "return" => Circuit::Right }).must_equal([user[:End], {"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}, nil])

      options.must_equal({"return"=>Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end

    it "runs from other Nested end" do
      user.(user[:Start], options = { "return" => Circuit::Left }).must_equal([user[:End], {"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]}, nil])

      options.must_equal({"return"=>Circuit::Left, "Read"=>1, "NextPage"=>[]})
    end

    #---
    #- Nested( activity, start_at )
    let(:with_nested_and_start_at) do
      Circuit::Activity(id: "user.blog") { |user|
        {
          user[:Start] => { Circuit::Right => nested=Circuit::Nested(blog, Blog::Next) },
          nested     => { blog[:End] => User::Relax },

          User::Relax => { Circuit::Right => user[:End] }
        }
      }
    end

    it "runs Nested from alternative start" do
      with_nested_and_start_at.(with_nested_and_start_at[:Start], options = { "return" => Circuit::Right }).
        must_equal( [with_nested_and_start_at[:End], {"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true}, nil] )

      options.must_equal({"return"=>Circuit::Right, "NextPage"=>[], "Relax"=>true})
    end

    #---
    #- Nested( activity ) { ... }
    describe "Nested with block" do
      let(:process) do
        class Workout
          def self.__call__(direction, options, flow_options)
            options[:workout]   = 9

            [ direction, options, flow_options ]
          end
        end

        nested = Circuit::Nested( Workout, "no start_at needed" ) do |activity:nil, start_at:nil, args:nil|
          activity.__call__(start_at, *args)
        end

        Circuit::Activity(id: "user.blog") { |user|
          {
            user[:Start] => { Circuit::Right => nested },
            nested     => { "no start_at needed" => User::Relax },

            User::Relax => { Circuit::Right => user[:End] }
          }
        }
      end

      it "runs Nested from alternative start" do
        process.(process[:Start], options = { "return" => Circuit::Right }).
          must_equal( [process[:End], {"return"=>Circuit::Right, :workout=>9, "Relax"=>true}, nil] )

        options.must_equal({"return"=>Circuit::Right, :workout=>9, "Relax"=>true})
      end
    end
  end
end
