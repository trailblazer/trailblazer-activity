# Circuit

_The Circuit of Life._

Circuit provides a simplified [flowchart](https://en.wikipedia.org/wiki/Flowchart) implementation with terminals (for example, start or end state), connectors and tasks (processes). It allows to define the flow (the actual *circuit*) and execute it.

Circuit refrains from implementing deciders. The decisions are encoded in the output signals of tasks.

`Circuit` and `workflow` use [BPMN](http://www.bpmn.org/) lingo and concepts for describing processes and flows. This document can be found in the [Trailblazer documentation](http://trailblazer.to/gems/trailblazer/circuit.html), too.

## Example


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

