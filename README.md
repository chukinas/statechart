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
    {:statechart, "~> 0.1.0"}
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
  - `statechart/2`
  - `state/3`
  - `>>>/2`
- **INSTANTIATE**
  - `MyStatechart.new/0`
- **MANIPULATE**
  - `trigger/2`
  - `states/1`
  - `in_state?/2`
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

## Other statechart / state machine libraries

With a plethora of other related libraries,
why did we need another one?
I wanted one that had very strict compile-time checks and a simple DSL.

Other libraries you might look into:
- `Machinery`
- `as_fsm`
- `gen_statem`
- https://github.com/sasa1977/fsm


<!--- StateChart moduledoc end -->

## Roadmap

- [X] compound states
- [ ] orthogonal states
- [ ] composability via subcharts
- [ ] on-enter and on-exit actions
- [ ] custom 'data' state
- [ ] final state
- [ ] state history (when re-entering a state, default to where you left off)
- [ ] transition history

## Tasks for 0.1.0 release

- add typespecs for public functions
- Make sure all Statechart functions/macros have a one-liner summary
