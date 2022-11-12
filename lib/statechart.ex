defmodule Statechart do
  [_ignored_intro, usage_section, _ignored] =
    "README.md" |> File.read!() |> String.split(~r/<!---.*moduledoc.*-->/, parts: 3)

  @external_resource "README.md"
  @moduledoc usage_section

  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroState
  alias Statechart.Build.MacroChart
  alias Statechart.Build.MacroOpts
  alias Statechart.Build.MacroTransition
  alias Statechart.Build.MacroSubchart
  alias Statechart.Build.MacroTransition
  alias Statechart.Machine
  alias Statechart.Schema.Location

  @type t(context) :: %Statechart.Machine{
          # LATER i don't like this key name
          statechart_module: atom(),
          context: context,
          current_local_id: local_id(),
          last_event_status: :ok | :error
        }

  @opaque local_id :: Location.local_id()
  @opaque t :: t(term)
  @type event :: term()
  @type state :: atom()
  @type action :: (context() -> context()) | (() -> :ok)
  @type context :: term

  defmacro __using__(_opts) do
    quote do
      import Statechart,
        only: [
          statechart: 0,
          statechart: 1,
          statechart: 2,
          subchart_new: 1,
          subchart_new: 2
        ]

      require MacroChart
      require AccStep
    end
  end

  @doc section: :build
  @doc """
  Create a statechart node.

  Examples

  arity-1 (name only)

      statechart do
        state :my_only_state
      end

  arity-2 (name and opts)

      statechart do
        state :state_with_opts, entry: fn -> IO.inspect "hello!" end
                                exit: fn -> IO.inspect "bye" end
      end

  arity-2 (name and do block)

      statechart do
        state :parent_state do
          state :child_state
        end
      end


  arity-3 (name and opts and do-block)
      statechart do
        state :parent_state,
          entry: fn -> IO.inspect("hello!") end,
          exit: fn -> IO.inspect("bye") end do
          state :child_state
        end
      end

  module's statechart.
  The way to have multiple nodes sharing the same name is to define statechart
  partials in separate module and then insert those partials into a parent statechart.

  #{MacroOpts.docs(:state)}
  """
  @spec state(state(), Keyword.t(), term()) :: term
  defmacro state(name, opts, do_block)
  defmacro state(name, opts, do: block), do: MacroState.build_ast(name, opts, block)

  @doc """
  Create a statechart node.

  See `state/3` for details
  """
  @doc section: :build
  @spec state(state(), Keyword.t() | term()) :: term
  defmacro state(name, opts_or_do_block \\ [])
  defmacro state(name, do: block), do: MacroState.build_ast(name, [], block)
  defmacro state(name, opts), do: MacroState.build_ast(name, opts, nil)

  @doc section: :build
  @doc """
  Create and register a statechart to this module.

  ```
  defmodule ToggleStatechart do
    use Statechart

    statechart do
      state :on, default: true, do: :TOGGLE >>> :off
      state :off, do: :TOGGLE >>> :on
    end
  end
  ```
  #{MacroOpts.docs(:statechart)}
  """

  @doc section: :build
  defmacro statechart(opts, do_block)
  defmacro statechart(opts, do: block), do: MacroChart.build_ast(:statechart, opts, block)

  @doc """
  Create or register a statechart to this module.

  See `statechart/2` for details.
  """
  @doc section: :build
  defmacro statechart(opts_or_do_block \\ [])

  defmacro statechart(do: block), do: MacroChart.build_ast(:statechart, [], block)
  defmacro statechart(opts), do: MacroChart.build_ast(:statechart, opts, nil)

  # FutureFeature
  @doc false
  # Inject a chart defined in another module.
  # ## `StatechartError` raised when...
  # - `subchart/2` is passed anything besides the name of a module that containing a `statechart/2` call
  # - `state/2` is called outside of a `statechart` block
  defmacro subchart(name, module, opts \\ [], do_block \\ [do: nil])

  defmacro subchart(name, module, opts, do: block) do
    MacroSubchart.build_ast(name, module, opts, block)
  end

  # LATER rename to subchart, add doc, and make public
  # have to then remove the current subchart and absorb its functionality into `state`
  _doc = """
  blarg

  blarg

  #{MacroOpts.docs(:subchart)}
  """

  @doc false
  defmacro subchart_new(), do: MacroChart.build_ast(:subchart, [], nil)
  @doc false
  defmacro subchart_new(do: block), do: MacroChart.build_ast(:subchart, [], block)

  defmacro subchart_new(opts) do
    MacroChart.build_ast(:subchart, opts, nil)
  end

  @doc false
  defmacro subchart_new(opts, block), do: MacroChart.build_ast(:subchart, opts, block)
  @doc section: :build
  @doc """
  Register a transtion from an event and target state.
  """
  defmacro event >>> target_state do
    MacroTransition.build_ast(event, target_state)
  end

  @doc section: :manipulate
  @doc """
  Get current context data.
  """
  @spec context(t(context)) :: context when context: var
  defdelegate context(statechart), to: Machine

  @doc false
  defmacro root() do
    quote do: __MODULE__
  end

  @doc section: :manipulate
  @doc """
  Send an event to the statechart
  """
  @spec trigger(t(context), event) :: t(context) when context: var
  defdelegate trigger(statechart, event), to: Machine

  @doc section: :manipulate
  @doc """
  Determine if the given state is in the given compound state
  """
  @spec in_state?(t, state) :: boolean
  defdelegate in_state?(statechart, state), to: Machine

  @doc section: :manipulate
  @doc """
  Returns `:ok` if last event was valid and caused a transition
  """
  @spec last_event_status(t) :: :ok | :error
  defdelegate last_event_status(statechart), to: Machine

  @doc section: :manipulate
  @doc """
  Get the current compound state
  """
  @spec states(t) :: [state]
  defdelegate states(statechart), to: Machine, as: :states
end
