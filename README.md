# Activity

An _activity_ is a collection of connected _tasks_ with one _start event_ and one (or many) _end_ events.

## Installation

To use activities you need one gem, only.

```ruby
gem "trailblazer-activity"
```

## Overview

> Since TRB 2.1, we use [BPMN](http://www.bpmn.org/) lingo and concepts for describing workflows and processes.

An activity is a workflow that contains one or several tasks. It is the main concept to organize control flow in Trailblazer.

The following diagram illustrates an exemplary workflow where a user writes and publishes a blog post.

<img src="http://trb.to/images/diagrams/blog-bpmn1.png">

After writing and spell-checking, the author has the chance to publish the post or, in case of typos, go back, correct, and go through the same flow, again. Note that there's only a handful of defined transistions, or connections. An author, for example, is not allowed to jump from "correct" into "publish" without going through the check.

The `activity` gem allows you to define this *activity* and takes care of implementing the control flow, running the activity and making sure no invalid paths are taken.

Your job is solely to implement the tasks and deciders put into this activity - Trailblazer makes sure it is executed it in the right order, and so on.

To eventually run this activity, three things have to be done.

1. The activity needs be defined. Easiest is to use the [Activity.from_hash builder](#activity-fromhash).
2. It's the programmer's job (that's you!) to implement the actual tasks (the "boxes"). Use [tasks for that](#task).
3. After defining and implementing, you can run the activity with any data [by `call`ing it](#activity-call).

## Operation vs. Activity

An `Activity` allows to define and maintain a graph, that at runtime will be used as a "circuit". Or, in other words, it defines the boxes, circles, arrows and signals between them, and makes sure when running the activity, the circuit with your rules will be executed.

Please note that an `Operation` simply provides a neat DSL for creating an `Activity` with a railway-oriented wiring (left and right track). An operation _always_ maintains an activity internally.

```ruby
class Create < Trailblazer::Operation
  step :exists?, pass_fast: true
  step :policy
  step :validate
  fail :log_err
  step :persist
  fail :log_db_err
  step :notify
end
```

Check the operation above. The DSL to create the activity with its graph is very different to `Activity`, but the outcome is a simple activity instance.

<img src="http://trb.to/images/graph/op-vs-activity.png">

When `call`ing an operation, several transformations on the arguments are applied, and those are passed to the `Activity#call` invocation. After the activity finished, its output is transformed into a `Result` object.

## Activity

To understand how an activity works and what it performs in your application logic, it's easiest to see how activities are defined, and used.

## Activity: From_Hash

Instead of using an operation, you can manually define activities by using the `Activity.from_hash` builder.

```ruby
activity = Activity.from_hash do |start, _end|
  {
    start            => { Trailblazer::Activity::Right => Blog::Write },
    Blog::Write      => { Trailblazer::Activity::Right => Blog::SpellCheck },
    Blog::SpellCheck => { Trailblazer::Activity::Right => Blog::Publish,
                          Trailblazer::Activity::Left => Blog::Correct },
    Blog::Correct    => { Trailblazer::Activity::Right => Blog::SpellCheck },
    Blog::Publish    => { Trailblazer::Activity::Right => _end }
  }
end
```


The block yields a generic start and end event instance. You then connect every _task_ in that hash (hash keys) to another task or event via the emitted _signal_.

## Activity: Call

To run the activity, you want to `call` it.

```ruby
my_options = {}
last_signal, options, flow_options, _ = activity.( nil, my_options, {} )
```

1. The `start` event is `call`ed and per default returns the generic _signal_`Trailblazer::Activity::Right`.
2. This emitted (or returned) signal is connected to the next task `Blog::Write`, which is now `call`ed.
3. `Blog::Write` emits another `Right` signal that leads to `Blog::SpellCheck` being `call`ed.
4. `Blog::SpellCheck` defines two outgoing signals and hence can decide what next task to call by emitting either `Right` if the spell check was ok, or `Left` if the post contains typos.
5. ...and so on.

<img src="http://trb.to/images/graph/blogpost-activity.png">

Visualizing an activity as a graph makes it very straight-forward to understanding the mechanics of the flow.


Note how signals translate to edges (or connections) in the graph, and tasks become vertices (or nodes).

The return values are the `last_signal`, which is usually the end event (they return themselves as a signal), the last `options` that usually contains all kinds of data from running the activity, and additional args.

## More

The [full documentation](http://trb.to/gems/activity/0.2/api.html) for this gem and many more interesting things can be found on the Trailblazer website.
