def key_method
end

map = {
  method(:key_method) => 1
}

puts map.key?(method(:key_method)) # true



map = {
  method(:key_method) => 1
}

map.compare_by_identity

puts map.key?(method(:key_method)) # false
