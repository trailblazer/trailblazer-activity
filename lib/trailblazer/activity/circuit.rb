module Trailblazer
  class Activity
    # A circuit is run using {Circuit::Processor}.
    class Circuit < Struct.new(:map, :start_task, :termini, :config, keyword_init: true)
    end
  end
end
