module Trailblazer
  class Activity
    # Config API allows you to read and write immutably to the activity's
    # {:config} field. Most of the times, this only contains {:wrap_static}.
    module Config
      module_function

      def set(config, *args)
        if args.size == 2
          key, value = *args

          config = config.merge(key => value)
        else
          directive, key, value = *args

          config = config.merge( directive => {}.freeze ) unless config.key?(directive)

          directive_hash = config[directive].merge(key => value)
          config = config.merge( directive => directive_hash.freeze )
        end

        config
      end

      def get(config, *args)
        directive, key = *args

        return config[directive] if args.size == 1
        return config[directive][key] if config.key?(directive)

        nil
      end
    end
  end
end
