require "test_helper"

class OptionTest < Minitest::Spec
  def assert_result(result)
    result.must_equal( [{:a=>1}, 2, {:b=>3}] )

      positional.inspect.must_equal %{{:a=>1}}
      keywords.inspect.must_equal %{{:a=>2, :b=>3}}
  end

  describe "positional and kws" do
    class Step
      def with_positional_and_keywords(options, a:nil, **more_options)
        [ options, a, more_options ]
      end
    end

    WITH_POSITIONAL_AND_KEYWORDS = ->(options, a:nil, **more_options) do
      [ options, a, more_options ]
    end

    class WithPositionalAndKeywords
      def self.call(options, a:nil, **more_options)
        [ options, a, more_options ]
      end
    end

    let(:positional) { { a: 1 } }
    let(:keywords)   { { a: 2, b: 3 } }

    it ":method" do
      step = Step.new

      # positional = { a: 1 }
      # keywords   = { a: 2, b: 3 }

      option = Trailblazer::Option(:with_positional_and_keywords)

      assert_result option.( positional, keywords, exec_context: step )
    end

    it "-> {} lambda" do
      option = Trailblazer::Option(WITH_POSITIONAL_AND_KEYWORDS)

      assert_result option.( positional, keywords, { exec_context: "something" } )
    end

    it "callable" do
      option = Trailblazer::Option(WithPositionalAndKeywords)

      assert_result option.( positional, keywords, { exec_context: "something" } )
    end
  end

  describe "positionals" do
    def assert_result_pos(result)
      result.must_equal( [1,2, [3, 4]] )
    end

    class Step
      def with_positionals(a, b, *args)
        [ a, b, args ]
      end
    end

    WITH_POSITIONALS = ->(a, b, *args) do
      [ a, b, args ]
    end

    class WithPositionals
      def self.call(a, b, *args)
        [ a, b, args ]
      end
    end

    let(:positionals) { [1, 2, 3, 4] }

    it ":method" do
      step = Step.new

      option = Trailblazer::Option(:with_positionals)

      assert_result_pos option.( *positionals, exec_context: step )
    end

    it "-> {} lambda" do
      option = Trailblazer::Option(WITH_POSITIONALS)

      assert_result_pos option.( *positionals, { exec_context: "something" } )
    end

    it "callable" do
      option = Trailblazer::Option(WithPositionals)

      assert_result_pos option.( *positionals, { exec_context: "something" } )
    end
  end
end
