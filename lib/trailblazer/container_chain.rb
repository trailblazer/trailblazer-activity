# @private
class Trailblazer::Context::ContainerChain # used to be called Resolver.
  # Keeps a list of containers. When looking up a key/value, containers are traversed in
  # the order they were added until key is found.
  #
  # Required Container interface: `#key?`, `#[]`.
  #
  # @note ContainerChain is an immutable data structure, it does not support writing.
  # @param containers Array of <Container> objects (splatted)
  def initialize(containers, to_hash: nil)
    @containers = containers
    @to_hash    = to_hash
  end

  # @param name Symbol or String to lookup a value stored in one of the containers.
  def [](name)
    self.class.find(@containers, name)
  end

  # @private
  def key?(name)
    @containers.find { |container| container.key?(name) }
  end

  def self.find(containers, name)
    containers.find { |container| container.key?(name) && (return container[name]) }
  end

  def keys
    @containers.collect(&:keys).flatten
end

  # @private
  def to_hash
    return @to_hash.(@containers) if @to_hash # FIXME: introduce pattern matching so we can have different "transformers" for each container type.
    @containers.each_with_object({}) { |container, hash| hash.merge!(container.to_hash) }
  end
end

# alternative implementation:
# containers.reverse.each do |container| @mutable_options.merge!(container) end
#
# benchmark, merging in #initialize vs. this resolver.
#                merge     39.678k (± 9.1%) i/s -    198.700k in   5.056653s
#             resolver     68.928k (± 6.4%) i/s -    342.836k in   5.001610s
