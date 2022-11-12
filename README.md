# StateChart

<!--- StateChart moduledoc start -->

A pure-Elixir implementation of statecharts inspired by

- David Harel's [Statecharts: a visual formalism for complex systems](https://www.sciencedirect.com/science/article/pii/0167642387900359) paper
- David Khourshid's JavaScript [XState](https://xstate.js.org/docs/) library

## Installation

This package can be installed by adding `statechart` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statechart, "~> 0.2.0"}
  ]
end
```

## Concepts

We'll model a simple traffic light to illustrate some statechart concepts.

![traffic light diagram](assets/traffic_light.jpg)

- This "machine" defaults to the `off` state (that's what the dot-arrow signifies).
- If we then send the machine a `TOGGLE` event, it transitions to the `on` state.
  From there, it automatically drops into the `red` state (again, because of the dot-arrow).
  At this point, the machine is in both the `on` and `red` states.
- If we send it a `NEXT` event, we transition to the `green` state (which you can also think of as the `on/green` state).
  Another `NEXT` event, and we transition to the `yellow` state.
  In this way, the light will just keep cycling through the colors.
- If we send it a `TOGGLE` at this point, it will transition back to `off`.
- If we now send the machine a `NEXT` event (while it's in the `off` state), nothing happens.

## Usage

There are three steps to modeling via the `Statechart` library:
- **DEFINE**
  - Start with a `statechart/2` block.
  - Define states with `state/3`. Nest as deeply as you want.
  - Define transitions using `>>>/2`.
- **INSTANTIATE**
  - `MyStatechart.new/0`
- **MANIPULATE**
  - Send events via `trigger/2`.
  - Get current nested state via `states/1`.
  - `in_state?/2`
  - Get current context via `context/1`.
  - `last_event_status/1`

We'll model the above traffic light using these three steps.

### DEFINE

```elixir
defmodule TrafficLight do
  use Statechart

  statechart default: :off do
    state :off do
      :TOGGLE >>> :on
    end

    state :on, default: :red do
      :TOGGLE >>> :off
      state :red,    do: :NEXT >>> :green
      state :yellow, do: :NEXT >>> :red
      state :green,  do: :NEXT >>> :yellow
    end
  end
end
```

### INSTANTIATE

The module containing your statechart definition automatically has a `new/0` function injected into it.

```elixir
traffic_light = TrafficLight.new()
```

It returns you a `t:statechart/0` struct that you then pass to all the 'MANIPULATE' functions.

### MANIPULATE

The machine starts in the `off` state:
```elixir
[:off] = Statechart.states(traffic_light)
true   = Statechart.in_state?(traffic_light, :off)
false  = Statechart.in_state?(traffic_light, :on)
```

Send it a `NEXT` event without it being on yet:
```elixir
traffic_light = Statechart.trigger(traffic_light, :NEXT)
# Still off...
true = Statechart.in_state?(traffic_light, :off)
# ...but we can see that the last event wasn't valid:
:error = Statechart.last_event_status(traffic_light)
```

Let's turn it on:
```elixir
traffic_light = Statechart.trigger(traffic_light, :TOGGLE)
[:on, :red]   = Statechart.states(traffic_light)
true  = Statechart.in_state?(traffic_light, :on)
true  = Statechart.in_state?(traffic_light, :red)
false = Statechart.in_state?(traffic_light, :off)
false = Statechart.in_state?(traffic_light, :green)
```

**Now** the `NEXT` events will have an effect:
```elixir
traffic_light = Statechart.trigger(traffic_light, :NEXT)
[:on, :green] = Statechart.states(traffic_light)
```

## Error-checking

`Statechart` has robust compile-time checking.
For example, compiling this module will result in a `StatechartError`
at the `state :on` line.

```elixir
defmodule ToggleStatechart do
  use Statechart

  statechart default: :on do
    # Whoops! We've misspelled "off":
    state :on, do: :TOGGLE >>> :of
    state :off, do: :TOGGLE >>> :on
  end
end
```

## Actions and Context (Harel §5)

An action is an instantaneous effect that can happen when entering or exiting a state.
Context is a chunk of data that the statechart is aware of.

If you were modeling a lightswitch, you might want to keep track of how many cycles it's undergone.

    defmodule LightSwitch do
      use Statechart
      statechart default: :off,
                 context: {non_neg_integer, 0} do
        state :on, entry: &(&1 + 1), do: :OFF >>> :off
        state :off, do: :ON >>> :on
      end
    end

In this example we see:
- The context type (`non_neg_integer()`) and initial value (`0`) declared using the `:context` option on `statechart/2`.
  When this statechart is instantiated, it will start with a context of `0`.
- Every time the switch is turned on, the context gets incremented by 1.
  This is because the `:on` state has a "entry action" of `&(&1 + 1)`.

### Multiple Actions

In statecharts where multiple actions are declared per state and/or where states are nested,
many actions might take place as a result of a single event.
In these cases, order matters.
Let's look at a contrived example.

    defmodule MathDoohickey do
      use Statechart
      statechart default: :alpaca,
                 context: {pos_integer, 1}
                 transition: {:ALPHA, :beetle} do
        state :alpaca, entry: &(&1 + 1),
                       entry: &(&1 * 3),
                       exit: &(&1 - 2)
        state :beetle, entry: fn val -> val - 1 end
      end
    end

When this chart is instantiated (`statechart = MathDoohickey.new()`),
the context is modified from its initial value of `1` to `6`.
Note the order of operations here.
The first action added one (`1 + 1 = 2`) and the second action multiplied by three (`2 * 3 = 6`).

When we trigger the `:ALPHA` event (`statechart = Statechart.trigger(statechart, :ALPHA)`),
we exit `:alpaca`, then enter `:beetle`, giving us a new context of `3`.
The first action (from exiting `:alpaca`) subtracted two (`6 - 2 = 4`).
The second action (from entering `:beetle`) subtracted one (`4 - 1 = 3`).

### Arity

In the examples above, all the action functions were arity-1.
They are passed a context and return a transformed context.

An action can also have an arity of 0. Usually this is for applying side effects.

### Default Context

`:context` is an optional key for `statechart/2`.
If left out, the context type defaults to `t:term/0` and the value to `nil`.

## Other statechart / state machine libraries

With a plethora of other related libraries,
why did we need another one?
I wanted one that had very strict compile-time checks and a simple DSL.

Other libraries you might look into:
- [`Machinery`](https://hexdocs.pm/machinery/Machinery.html)
- [`as_fsm`](https://hexdocs.pm/as_fsm/readme.html)
- [`GenStateMachine`](https://hexdocs.pm/gen_state_machine/GenStateMachine.html)
- [`StateMachine`](https://hexdocs.pm/state_machine/StateMachine.html)
- [`gen_statem`](https://www.erlang.org/doc/man/gen_statem.html)
- [`fsm`](https://github.com/sasa1977/fsm)


## Roadmap

- [X] `v0.1.0` hierarchical states (see Harel, §2)
- [X] `v0.1.0` defaults (see Harel, Fig.6)
- [X] `v0.2.0` context and actions (see Harel, §5)
- [ ] actions associated with events (see γ/W in Harel, Fig.37)
- [ ] events triggered by actions (see β in Harel, Fig.37)
- [ ] orthogonality (see Harel, §3)
- [ ] event conditions
- [ ] composability via subcharts
- [ ] final state
- [ ] state history (see Harel, Fig.10)
- [ ] transition history

<!--- StateChart moduledoc end -->

