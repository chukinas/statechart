defmodule Statechart.Machine do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Create and manipulate state machines defined by `Statechart.statechart/2`

    The above three "steps" are all about declaring a statechart in a safe, robust way.
    In `Statechart`, when we say 'statechart', you can think of it as a template
    (similar to a class in OOO).
    To do anything meaningful with the statechart, you need to first instantiate a
    machine (similar to an object in OOO) that is built from that template.
    We will transform this data structure as we pass events to it.

    ```
    iex> defmodule ToggleStatechart do
    ...>   use Statechart
    ...>   statechart default: :on do
    ...>     state :on do
    ...>       :TOGGLE >>> :off
    ...>     end
    ...>     state :off do
    ...>       :TOGGLE >>> :on
    ...>     end
    ...>   end
    ...> end
    ...>
    ...> toggle_machine = ToggleStatechart.machine()
    ...> Machine.state(toggle_machine)
    :on
    iex> toggle_machine = Machine.transition(toggle_machine, :TOGGLE)
    ...> Machine.state(toggle_machine)
    :off
    ```
    """

  use TypedStruct
  alias Statechart.Schema
  alias Statechart.Schema.Location
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  #####################################
  # TYPES

  # LATER incorporate non-zero-arity types into TypedStruct library
  typedstruct enforce: true do
    field :statechart_module, module()
    field :context, term
    field :current_local_id, Location.local_id()
    field :last_event_status, :ok | :error, default: :ok
  end

  @type t(context) :: %__MODULE__{
          statechart_module: atom(),
          context: context,
          current_local_id: Location.local_id(),
          last_event_status: :ok | :error
        }

  @typedoc """
  This is the event type
  """
  @type event :: any

  #####################################
  # CONSTRUCTORS

  @type action(context) :: (context -> context)

  defp apply_actions(initial_context, actions) do
    Enum.reduce(actions, initial_context, fn
      action, context when is_function(action, 0) ->
        action.()
        context

      action, context when is_function(action, 1) ->
        action.(context)
    end)
  end

  @doc false
  # @spec __new__(module, context) :: t(context) when context: var
  def __new__(statechart_module, init_context) when is_atom(statechart_module) do
    %Schema{} = schema = statechart_module.__schema__()
    start_local_id = Schema.starting_local_id(schema)
    actions = Schema.fetch_init_actions!(schema, local_id: start_local_id)
    context = apply_actions(init_context, actions)

    %__MODULE__{
      statechart_module: statechart_module,
      context: context,
      current_local_id: start_local_id
    }
  end

  #####################################
  # REDUCERS

  @doc """
  Send an `t:event/0` to an `t:t/1`


  The `statechart/3` macro injects a `t:t/1` function into the module,
  which is then called as follows:
  ```
  defmodule ToggleStatechart do
    use Statechart
    statechart do
      state :stay_here_forever, default: true
    end
  end

  machine = ToggleStatechart.machine()
  ```

  With the machine now available
  """
  @spec trigger(t, event()) :: t
  def trigger(%__MODULE__{} = machine, event) do
    schema = __schema__(machine)
    origin_local_id = machine.current_local_id

    with {:ok, destination_local_id} <-
           Schema.destination_local_id_from_event(schema, event, origin_local_id),
         {:ok, actions} <-
           Schema.fetch_actions(schema, [local_id: origin_local_id],
             local_id: destination_local_id
           ) do
      struct!(machine,
        last_event_status: :ok,
        current_local_id: destination_local_id
      )
      |> Map.update!(:context, &apply_actions(&1, actions))
    else
      _ -> put_in(machine.last_event_status, :error)
    end
  end

  #####################################
  # CONVERTERS

  @doc """
  Get the machine's current state.
  """
  @spec state(t()) :: Statechart.state()
  def state(%__MODULE__{current_local_id: local_id} = machine) do
    machine
    |> __schema__
    |> Schema.tree()
    |> Tree.fetch_node!(local_id: local_id)
    |> Node.name()
  end

  @spec context(t(context)) :: context when context: var
  def context(%__MODULE__{context: val}), do: val

  @spec states(t) :: [Statechart.state()]
  def states(%__MODULE__{statechart_module: module, current_local_id: local_id}) do
    nodes =
      module.__tree__()
      |> Tree.fetch_ancestors_and_self!(local_id: local_id)

    nodes
    |> Stream.filter(&(!Node.local_root?(&1)))
    |> Enum.map(&Node.name/1)
  end

  def in_state?(machine, state_name) do
    state_name in states(machine)
  end

  @doc """
  Get the `t:module/0` that defines the machine's statechart.
  """
  @spec statechart_module(t()) :: module
  def statechart_module(%__MODULE__{statechart_module: val}), do: val

  @spec __schema__(t) :: Schema.t()
  defp __schema__(%__MODULE__{statechart_module: module}) do
    module.__schema__
  end

  def last_event_status(%__MODULE__{last_event_status: val}), do: val
end
