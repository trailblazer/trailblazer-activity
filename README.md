# Circuit

_The Circuit of Life._

Circuit provides a simplified [flowchart](https://en.wikipedia.org/wiki/Flowchart) implementation with terminals (for example, start or end state), connectors and tasks (processes). It allows to define the flow (the actual *circuit*) and execute it.

Circuit refrains from implementing deciders. The decisions are encoded in the output signals of tasks.

`Circuit` and `workflow` use [BPMN](http://www.bpmn.org/) lingo and concepts for describing processes and flows. This document can be found in the [Trailblazer documentation](http://trailblazer.to/gems/workflow/circuit.html), too.

> The `circuit` gem is the lowest level of abstraction and is used in `operation` and `workflow`, which both provide higher-level APIs for the Railway pattern and complex BPMN workflows.

## Installation

To use circuits, activities and nested tasks, you need one gem, only.

```ruby
gem "trailblazer-circuit"
```

The `trailblazer-circuit` gem is often just called the `circuit` gem. It ships with the `operation` gem and implements the internal Railway.

## Overview

The following diagram illustrates a common use-case for `circuit`, the task of publishing a blog post.

<img src="http://trailblazer.to/images/diagrams/blog-bpmn1.png">

After writing and spell-checking, the author has the chance to publish the post or, in case of typos, go back, correct, and go through the same flow, again. Note that there's only a handful of defined transistions, or connections. An author, for example, is not allowed to jump from "correct" into "publish" without going through the check.

The `circuit` gem allows you to define this *activity* and takes care of implementing the control flow, running the activity and making sure no invalid paths are taken.

Your job is solely to implement the tasks and deciders put into this activity - you don't have to take care of executing it in the right order, and so on.

## Definition

In order to define an activity, you can use the BPMN editor of your choice and run it through the Trailblazer circuit generator, use our online tool (if [you're a PRO member](http://pro.trailblazer.to)) or simply define it using plain Ruby.

```ruby
activity = Activity.from_hash do |start, _end|
  {
    start            => { Circuit::Right => Blog::Write },
    Blog::Write      => { Circuit::Right => Blog::SpellCheck },
    Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
    Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
    Blog::Publish    => { Circuit::Right => _end }
  }
end
```

The `Activity` function is a convenient tool to create an activity. Note that the yielded object allows to access *events* from the activity, such as the `Start` and `End` event that are created per default.

This defines the control flow - the next step is to actually implement the tasks in this activity.

## Task

A *task* usually maps to a particular box in your diagram. Its API is very simple: a task needs to expose a `call` method, allowing it to be a lambda or any other callable object.

```ruby
module Blog
  Write = ->(direction, options, *flow) do
    options[:content] = options[:content].strip
    [ Circuit::Right, options, *flow ]
  end
end
```

It receives all arguments returned from the task run before. This means a task should return everything it receives.

To transport data across the flow, you can change the return value. In this example, we use one global hash `options` that is passed from task to task and used for writing.

The first return value is crucial: it dictates what will be the next step when executing the flow.

For example, the `SpellCheck` task needs to decide which route to take.

```ruby
SpellCheck = ->(direction, options, *flow) do
  direction = SpellChecker.error_count(options[:content]) ? Circuit::Right : Circuit::Left
  [ direction, options, *flow ]
end
```

It's as simple as returning the appropriate signal.

> You can use any object as a direction signal and return it, as long as it's defined in the circuit.

## Call

After defining circuit and implementing the tasks, the circuit can be executed using its very own `call` method.

```ruby
direction, options, flow = activity.(
  nil,
  { content: "Let's start writing   " } # gets trimmed in Write.
)
```

The first argument is where to start the circuit. Usually, this will be the activity's `Start` event accessable via `activity[:Start]`.

All options are passed straight to the first task, which in turn has to make sure it returns an appropriate result set.

The activity's return set is the last run task and all arguments from the last task.

```ruby
direction #=> #<End: default {}>
options   #=> {:content=>"Let's start writing"}
```

As opposed to higher abstractions such as `Operation`, it is completely up to the developer what interfaces they provide to tasks and their return values. What is a mutable hash here could be an explicit array of return values in another implementation style, and so on.

## Tracing

For debugging or simply understanding the flows of circuits, you can use tracing.

```ruby
activity = Activity.from_hash do |start, _end|
  # Blog::Write=>"Blog::Write",Blog::SpellCheck=>"Blog::SpellCheck",Blog::Correct=>"Blog::Correct", Blog::Publish=>"Blog::Publish" }) { |evt|
  {
    start      => { Circuit::Right => Blog::Write },
    Blog::Write      => { Circuit::Right => Blog::SpellCheck },
    Blog::SpellCheck => { Circuit::Right => Blog::Publish, Circuit::Left => Blog::Correct },
    Blog::Correct    => { Circuit::Right => Blog::SpellCheck },
    Blog::Publish    => { Circuit::Right => _end }
  }
end
```

The second argument to `Activity` takes debugging information, so you can set readable names for tasks.

When invoking the activity, the `:runner` option will activate tracing and write debugging information about any executed task onto the `:stack` array.

```ruby
stack, _ = Circuit::Trace.( activity,
  nil,
  { content: "Let's start writing" }
)
```

The `stack` can then be passed to a presenter.

```ruby
Circuit::Trace::Present.tree(stack)
 |--> #<Start: default {}>{:content=>"Let's start writing"}
 |--> Blog::Write{:content=>"Let's start writing"}
 |--> Blog::SpellCheck{:content=>"Let's start writing"}
 |--> Blog::Publish{:content=>"Let's start writing"}
 `--> #<End: default {}>{:content=>"Let's start writing"}
 ```

Tracing is extremely efficient to find out what is going wrong and supersedes cryptic debuggers by many times. Note that tracing also works for deeply nested circuits.

> 🌅 In future versions of Trailblazer, our own debugger will take advantage of the explicit, traceable nature of circuits and also integrate with Ruby's exception handling.
> Also, more options will make debugging of complex, nested workflows easier.

## Event

* how to add more ends, etc.

## Nested

## Operation

If you need a higher abstraction of `circuit`, check out Trailblazer's [operation](http://trailblazer.to/gems/operation/2.0/api.html) implemenation which provides a simple Railway-oriented interface to create linear circuits.
