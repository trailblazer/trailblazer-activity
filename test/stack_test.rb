require "test_helper"

class StackTest < Minitest::Spec
  it do
    stack = Trailblazer::Activity::Trace::Stack.new
    stack.indent!
    stack << 1
    stack << 2
    stack.indent!
    stack << 3
    stack << 4
    stack.indent!
    stack << 5
    stack << 6
    stack.unindent!
    stack << 7
    stack << 8
    stack.unindent!
    stack << 9
    stack << 10
    # stack.unindent!

    stack.to_a.inspect.must_equal %{[<Level>[1, 2, <Level>[3, 4, <Level>[5, 6], 7, 8], 9, 10]]}
  end
end
