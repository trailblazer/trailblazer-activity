# 0.0.10

* Introduce `Context::ContainerChain` to eventually replace the heavy-weight `Skill` object.
* Fix a bug in `Option` where wrong args were passed when used without `flow_options`.

# 0.0.9

* Fix `Context#[]`, it returned `nil` when it should return `false`.

# 0.0.8

* Make `Trailblazer::Option` and `Trailblazer::Option::KW` a mix of lambda and object so it's easily extendable.

# 0.0.7

* It is now `Trailblazer::Args`.

# 0.0.6

* `Wrapped` is now `Wrap`. Also, a consistent `Alterations` interface allows tweaking here.

# 0.0.5

* The `Wrapped::Runner` now applies `Alterations` to each task's `Circuit`. This means you can inject `:task_alterations` into `Circuit#call`, which will then be merged into the task's original circuit, and then run. While this might sound like crazy talk, this allows any kind of external injection (tracing, input/output contracts, step dependency injections, ...) for specific or all tasks of any circuit.

# 0.0.4

* Simpler tracing with `Stack`.
* Added `Context`.
* Simplified `Circuit#call`.

# 0.0.3

* Make the first argument to `#Activity` (`@name`) always a Hash where `:id` is a reserved key for the name of the circuit.

# 0.0.2

* Make `flow_options` an immutable data structure just as `options`. It now needs to be returned from a `#call`.

# 0.0.1

* First release into an unsuspecting world. 🚀
