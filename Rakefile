require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"] - FileList["test/ruby_with_unfixed_compaction_test.rb"]
end

task default: %i[test]

Rake::TestTask.new(:test_gc_bug) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/ruby_with_unfixed_compaction_test.rb"]
end
