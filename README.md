# Circuit

_The Circuit of Life._


## minimize Nil errors

* kw args guard input

## ARCHITECTURE

* Theoretically, you can build any network of circuits with `Circuit`, only.
* DSL: `Activity` helps you building circuits and wiring them by exposing its events.
* `Task` is Options::KW. It will be converted to be its own circuit, so you can override and change things like KWs, what is returned, etc. ==> do some benchmarks, and play with circuit-compiled.

* An `Operation` simply is a `circuit`, with a limited, linear-only flow.



## Activity

An `Activity` has start and end events. While *events* in BPMN have behavior and might trigger listeners, in `circuit` an event is simply a state. The activity always ends in an `End` state. It's up to the user to interpret and trigger behavior.



## TODO:

* oPTIONS::kW

