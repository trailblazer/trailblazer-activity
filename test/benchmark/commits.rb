

commits = {
  "0.5.3" => "v0.5.3",
  "0.5.3" => "v0.5.3",
}

def run(tag)


  signal, (ctx, _) = Create.({})
  # pp ctx
end


commits.values[-2..-1].each do |tag|
  puts `git checkout #{tag}`
  result = `bundle exec ruby test/benchmark/ips.rb`
  raise result.inspect
end

`git checkout master`
