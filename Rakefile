require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  # t.test_files = FileList["test/**/*_test.rb"]
  t.test_files = ["test/node_test.rb", "test/adapter_test.rb", "test/builder_test.rb", "test/trace_test.rb",
    "test/wrap_runtime_test.rb",
    "test/internal-compat/wrap_test.rb",
    "test/internal-compat/each_test.rb",
  ]
end

task default: %i[test]
