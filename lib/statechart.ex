defmodule Statechart do
  [_ignored_intro, usage_section, _ignored] =
    "README.md" |> File.read!() |> String.split(~r/<!---.*moduledoc.*-->/, parts: 3)

  @external_resource "README.md"
  @moduledoc usage_section

  alias Statechart.Build.MacroOnEnterExit
  alias Statechart.Build.MacroState
  alias Statechart.Build.MacroStatechart
  alias Statechart.Build.MacroTransition
  alias Statechart.Build.MacroSubchart
  alias Statechart.Machine

  defmacro __using__(_opts) do
    quote do
      import Statechart, only: [statechart: 1, statechart: 2]
    end
  end

  @doc section: :build
  @doc """
  Create and register a statechart to this module.
  May only be used once per module.

  ```
  defmodule ToggleStatechart do
    use Statechart

    statechart do
      state :on, default: true, do: :TOGGLE >>> :off
      state :off, do: :TOGGLE >>> :on
    end
  end
  ```

  `statechart/2` accepts a `:module` option.
  In the below example,
  the module containing the statechart is `Toggle.Statechart`
  ```
  defmodule Toggle do
    use Statechart

    statechart module: Statechart do
      state :on, default: true, do: :TOGGLE >>> :off
      state :off, do: :TOGGLE >>> :on
    end
  end
  ```

  In this way, many statecharts may be declared easily in one file:
  ```
  defmodule MyApp.Statechart do
    use Statechart

    # module: MyApp.Statechart.Toggle
    statechart module: Toggle do
      state :on, default: true, do: :TOGGLE >>> :off
      state :off, do: :TOGGLE >>> :on
    end

    # module: MyApp.Statechart.Switch
    statechart module: Switch do
      state :on, default: true, do: :SWITCH_OFF >>> :off
      state :off, do: :SWITCH_ON >>> :on
    end
  end
  ```

  ## `StatechartError` raised when...
  - `statechart/2` is used more than once per module
  """
  defmacro statechart(opts \\ [], do_block)

  defmacro statechart(opts, do: block) do
    ast = MacroStatechart.build_ast(block, Keyword.put(opts, :include_public_api, true))

    case opts[:module] do
      nil ->
        quote do
          (fn -> unquote(ast) end).()
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)
          end
        end
    end
  end

  @doc false
  defmacro state(name) do
    MacroState.build_ast(name, [], nil)
  end

  @doc section: :build
  @doc """
  Create a statechart node.

  `name` must be an atom and must be unique amongst nodes defined in this
  module's statechart.
  The way to have multiple nodes sharing the same name is to define statechart
  partials in separate module and then insert those partials into a parent statechart.

  ## `StatechartError` raised when...
  - `name` is non-atom
  - `name` is non-unique (another node already has the same name)
  - assigning a default to a leaf node
  - a default targets a non-descendent
  - `state/2` is called outside of a `statechart` block
  """
  defmacro state(name, opts \\ [], do_block)

  defmacro state(name, opts, do: block) do
    MacroState.build_ast(name, opts, block)
  end

  # FutureFeature
  @doc false
  # Inject a chart defined in another module.
  # ## `StatechartError` raised when...
  # - `subchart/2` is passed anything besides the name of a module that containing a `statechart/2` call
  # - `state/2` is called outside of a `statechart` block
  defmacro subchart(name, module, do_block \\ [do: nil])

  defmacro subchart(name, module, do: block) do
    MacroSubchart.build_ast(name, module, block)
  end

  @doc section: :build
  @doc """
  Register a transtion from an event and target state.

  ## `StatechartError` raised when...
  - `event` is non-atom
  - `event` occurs elsewhere amongst this node's ancestors or descendents
  - `target_state` doesn't exist
  - `>>>/2` is called outside of a `state` block
  """
  defmacro event >>> target_state do
    MacroTransition.build_ast(event, target_state)
  end

  @doc false
  _future_doc = """
  Declare an action (zero-arity function) to be run when a node is entered or exited.

  There are two available actions:
  ```
  on enter: &do_something_when_entering_a_node/0
  on exit: &do_something_else_when_exiting/0
  ```

  ## Add action to statechart
  This can be used at the top level of a `Statechart.statechart/2`...
  ```
  defmodule ToggleStatechart do
    use Statechart

    statechart do
      on enter: fn -> IO.puts "ToggleStatechart.machine/0 was just called" end
      state :on, default: true, do: :TOGGLE >>> :off
      state :off, do: :TOGGLE >>> :on
      on exit: fn -> IO.puts "This will never print" end
    end
  end
  ```

  ## Add action to state node

  More often though, it is used inside of a state:
  ```
  defmodule ToggleStatechart do
    use Statechart

    statechart do
      state :on, default: true do
        on enter: fn -> IO.puts "Turn on" end
        :TOGGLE >>> :off
        on exit: fn -> IO.puts "Exit :on" end
      end

      state :off do
        on enter: fn -> IO.puts "Turn off" end
        :TOGGLE >>> :on
        on exit: fn -> IO.puts "Exit :off" end
      end
    end
  end
  ```

  These actions are then triggered as follows
  ```
  ToggleStatechart.machine()
  # "Turn on"
  |> Statechart.Machine.transition(:TOGGLE)
  # "Exit :on"
  # "Turn off"
  |> Statechart.Machine.transition(:TOGGLE)
  # "Exit :off"
  # "Turn on"
  |> Statechart.Machine.transition(:TOGGLE)
  # "Exit :on"
  # "Turn off"
  ```

  ## `StatechartError` raised when
  - it is passed anything other than a keyword list with a single key-value pair
  - the key is anything other than `t:Statechart.action_type/0`
  - `on2` is called outside of a `state` block
  """

  defmacro on(action_and_function)

  defmacro on([{action_type, action_fn}]) do
    MacroOnEnterExit.build_ast(action_type, action_fn)
  end

  @doc false
  defmacro root() do
    quote do: __MODULE__
  end

  @opaque statechart :: Statechart.Machine.t()
  @type event :: term()
  @type state :: term()

  @doc section: :manipulate
  @doc """
  Send an event to the statechart
  """
  @spec trigger(statechart, event) :: statechart
  defdelegate trigger(statechart, event), to: Machine

  @doc section: :manipulate
  @doc """
  Get the current compound state
  """
  @spec states(statechart) :: [state]
  defdelegate states(statechart), to: Machine, as: :states

  @doc section: :manipulate
  @doc """
  Determine if the given state is in the given compound state
  """
  @spec in_state?(statechart, state) :: boolean
  defdelegate in_state?(statechart, state), to: Machine

  @doc section: :manipulate
  @doc """
  Returns `:ok` is last event was valid and caused a transition
  """
  @spec last_event_status(statechart) :: :ok | :error
  defdelegate last_event_status(statechart), to: Machine
end
