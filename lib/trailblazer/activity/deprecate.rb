module Trailblazer
  class Activity
    module Deprecate
      module_function

      def warn(caller_location, message)
        location = caller_location ? location_for(caller_location) : nil
        warning  = [location, message].compact.join(" ")

        Kernel.warn %([Trailblazer] #{warning}\n)
      end

      def location_for(caller_location)
        line_no = caller_location.lineno

        %(#{caller_location.absolute_path}:#{line_no})
      end
    end
  end
end
