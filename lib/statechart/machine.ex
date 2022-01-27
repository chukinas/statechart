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

  typedstruct opaque: true, enforce: true do
    field :statechart_module, module()
    field :context, nil
    field :current_local_id, Location.local_id()
    field :last_event_status, :ok | :error, default: :ok
  end

  @typedoc """
  This is the event type
  """
  @type event :: any

  #####################################
  # CONSTRUCTORS

  @doc false
  @spec __new__(module) :: t()
  def __new__(statechart_module) do
    %Schema{} = schema = statechart_module.__schema__()
    start_local_id = Schema.starting_local_id(schema)

    %__MODULE__{
      statechart_module: statechart_module,
      context: nil,
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
  @spec transition(t, event()) :: t
  def transition(%__MODULE__{} = machine, event) do
    schema = __schema__(machine)
    origin_local_id = machine.current_local_id

    with {:ok, destination_local_id} <-
           Schema.destination_local_id_from_event(schema, event, origin_local_id),
         {:ok, actions} <-
           Schema.fetch_actions(schema, [local_id: origin_local_id],
             local_id: destination_local_id
           ) do
      _context =
        Enum.reduce(actions, machine.context, fn action, context ->
          action.(context)
        end)

      struct!(machine, last_event_status: :ok, current_local_id: destination_local_id)
    else
      _ -> put_in(machine.last_event_status, :error)
    end
  end

  def trigger(machine, event) do
    transition(machine, event)
  end

  #####################################
  # CONVERTERS

  @doc """
  Get the machine's current state.
  """
  @spec state(t()) :: Node.name()
  def state(%__MODULE__{current_local_id: local_id} = machine) do
    machine
    |> __schema__
    |> Schema.tree()
    |> Tree.fetch_node!(local_id: local_id)
    |> Node.name()
  end

  @spec states(t) :: [Node.name()]
  def states(%__MODULE__{statechart_module: module, current_local_id: local_id}) do
    nodes =
      module.__tree__()
      |> Tree.fetch_root_to_self!(local_id: local_id)

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
