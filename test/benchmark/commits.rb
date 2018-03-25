# be ruby test/benchmark/commits.rb

commits = {
  "ref-1" => "master",
  "ref-2" => "master",
}


results =
  commits.values[-2..-1].collect do |tag|
    puts `git checkout #{tag}`
    result = `bundle exec ruby test/benchmark/ips.rb`
    result = result.split("\n").last.split("-").last

    [tag, result]
  end

pp results

`git checkout master`
