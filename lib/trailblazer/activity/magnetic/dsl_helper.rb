module Trailblazer::Activity::Magnetic
  # Helpers such as Path, Output, End to be included into {Activity}.
  # They only delegate to DSLHelper.
  module DSLHelper
    extend Forwardable
    def_delegators :@builder, :Path
    def_delegators Builder::DSLHelper, :Output, :End
  end
end
