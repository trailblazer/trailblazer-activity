# Activity

Implements Intermediate, Implementation and compiler

The `activity` gem implements the runtime logic to invoke a new abstraction called "activities". Ideally, activities are defined using the [`dsl-linear` DSL gem](https://github.com/trailblazer/trailblazer-activity-dsl-linear).

A process is a set of arbitrary pieces of logic you define, chained together and put into a meaningful context by an activity. Activity lets you focus on the implementation of steps while Trailblazer takes care of the control flow.

Please find the [full documentation on the Trailblazer website](https://trailblazer.to/2.1/docs/activity.html).

## Example

In conjunction with [`dsl-linear`](https://github.com/trailblazer/trailblazer-activity-dsl-linear), the `activity` gem provides three default patterns to model processes: `Path`, `Railway` and `FastTrack`. Here's an example of what a railway activity could look like, along with some more complex connections (you can read more about Railway strategy in the [docs](https://trailblazer.to/2.1/docs/activity.html#activity-strategy-railway)).

```ruby
require "trailblazer-activity"
require "trailblazer-activity-dsl-linear"

class Memo::Update < Trailblazer::Activity::Railway
  # here goes your business logic
  #
  def find_model(ctx, id:, **)
    ctx[:model] = Memo.find_by(id: id)
  end

  def validate(ctx, params:, **)
    return true if params[:body].is_a?(String) && params[:body].size > 10
    ctx[:errors] = "body not long enough"
    false
  end

  def save(ctx, model:, params:, **)
    model.update_attributes(params)
  end

  def log_error(ctx, params:, **)
    ctx[:log] = "Some idiot wrote #{params.inspect}"
  end

  # here comes the DSL describing the layout of the activity
  #
  step :find_model
  step :validate, Output(:failure) => End(:validation_error)
  step :save
  fail :log_error
end
```

Visually, this would translate to the following circuit.

<img src="http://trailblazer.to/images/2.1/activity-readme-example.png">

You can run the activity by invoking its `call` method.

```ruby
ctx = { id: 1, params: { body: "Awesome!" } }

signal, (ctx, *) = Update.( [ctx, {}] )

pp ctx #=>
{:id=>1,
 :params=>{:body=>"Awesome!"},
 :model=>#<Memo body=nil>,
 :errors=>"body not long enough"}

pp signal #=> #<struct Trailblazer::Activity::End semantic=:validation_error>
```

With Activity, modeling business processes turns out to be ridiculously simple: You define what should happen and when, and Trailblazer makes sure _that_ it happens.

## Features

* Activities can model any process with arbitrary flow and connections.
* Nesting and compositions are allowed and encouraged (via Trailblazer's [`dsl-linear`](https://github.com/trailblazer/trailblazer-activity-dsl-linear) gem).
* Different step interfaces, manual processing of DSL options, etc is all possible.
* Steps can be any kind of callable objects.
* Tracing! (via Trailblazer's [`developer`](https://github.com/trailblazer/trailblazer-developer) gem)

## Operation

Trailblazer's [`Operation`](https://trailblazer.to/2.1/docs/operation.html#operation-overview) internally uses an activity to model the processes.

## Workflow
Activities can be formed into bigger compounds and using workflow, you can build long-running processes such as a moderated blog post or a parcel delivery. Also, you don't have to use the DSL but can use the [`editor`](https://trailblazer.to/2.1/docs/pro.html#pro-editor)instead(cool for more complex, long-running flows). Here comes a sample screenshot.

<img src="http://trailblazer.to/2.1/dist/img/flow.png">

## License

© Copyright 2018, Trailblazer GmbH

Licensed under the LGPLv3 license. We also offer a commercial-friendly [license](https://trailblazer.to/2.1/docs/pro.html#pro-license).
