require "benchmark/ips"

=begin
## Learning

=end

commits = {
  "0.5.3" => "v0.5.3",
  "0.5.3" => "master",
}


Benchmark.ips do |x|

  x.report("old_circuit_api_doublesplat") { old_circuit_api_doublesplat(old_signature, circuit_options) }
  x.report("old_circuit_api")             { old_circuit_api(old_signature, circuit_options) }

  x.compare!
end


