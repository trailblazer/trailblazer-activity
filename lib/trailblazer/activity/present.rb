module Trailblazer
  class Activity
    # Task < Array
    # [ input, ..., output ]

    module Trace
      # TODO: make this simpler.
      module Present
        module_function

        INDENTATION = "   |".freeze
        STEP_PREFIX = "-- ".freeze

        def default_renderer(task_node:, **)
          [ task_node[:level], %{#{task_node[:name]}} ]
        end

        def call(stack, level: 1, tree: [], renderer: method(:default_renderer), **options)
          tree(stack.to_a, level, tree: tree, renderer: renderer, **options)
        end

        def tree(stack, level, tree:, renderer:, **options)
          tree_for(stack, level, options.merge(tree: tree))

          nodes = tree.each_with_index.map do |task_node, position|
            renderer.(task_node: task_node, position: position, tree: tree)
          end

          render_tree_for(nodes)
        end

        def render_tree_for(nodes)
          nodes.map { |level, node|
            indentation = INDENTATION * (level -1)
            indentation = indentation[0...-1] + "`" if level == 1 || /End./.match(node) # start or end step
            indentation + STEP_PREFIX + node
          }.join("\n")
        end

        def tree_for(stack, level, tree:, **options)
          stack.each do |lvl| # always a Stack::Task[input, ..., output]
            input, output, nested = Trace::Level.input_output_nested_for_level(lvl)

            task = input.task

            graph = Introspect::Graph(input.activity)

            name = (node = graph.find { |node| node[:task] == task }) ? node[:id] : task
            name ||= task # FIXME: bullshit

            tree << { level: level, input: input, output: output, name: name, **options }

            if nested.any? # nesting
              tree_for(nested, level + 1, options.merge(tree: tree))
            end

            tree
          end
        end
      end
    end
  end
end
