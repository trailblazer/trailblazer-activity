
module Inspect
  def inspect
    "nice view!"
  end
end

module A
  extend Inspect

  def self.a
  end
end

# jruby 9.1.7
puts A.method(:a).inspect #=> #<Method: A.a>
# 2.5
puts A.method(:a).inspect #=> #<Method: nice view!.a>

