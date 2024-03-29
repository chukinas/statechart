defmodule Statechart.Schema.Node do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Synonymous with "state", a node is a point in the ordered tree.
    """

  use TypedStruct
  alias MPTree.Node, as: MPTreeNode
  alias Statechart.Schema.Location
  alias Statechart.Schema.Transition

  #####################################
  # TYPES

  # LATER I have entry and exit hardcoded all over the place. Fix.
  @type action_type :: :entry | :exit
  @type action_spec :: {action_type, Statechart.action()}

  typedstruct enforce: true do
    plugin MPTreeNode
    field :name, Statechart.state()
    field :location, Location.t(), enforce: false
    field :transitions, [Transition.t()], default: []
    field :default, Location.local_id(), enforce: false
    field :actions, [action_spec], default: []
    field :local_root?, boolean, default: false
  end

  #####################################
  # CONSTRUCTORS

  @spec root(Location.t()) :: t
  def root(%Location{} = location) do
    new(location.module, location)
    |> struct!(local_root?: true)
  end

  @spec new(atom, Location.t()) :: t
  def new(name, %Location{} = location) when is_atom(name) do
    %__MODULE__{name: name, location: location}
  end

  #####################################
  # REDUCERS

  def set_name(node, name) do
    struct!(node, name: name)
  end

  @spec put_transition(t, Transition.t()) :: t
  def put_transition(%__MODULE__{} = node, %Transition{} = transition) do
    Map.update!(node, :transitions, &[transition | &1])
  end

  #####################################
  # Validating Reducers

  @spec add_action(t, action_type(), term) :: t
  def add_action(%__MODULE__{actions: actions} = node, action_type, fun)
      when action_type in ~w/entry exit/a do
    new_actions = actions ++ [{action_type, fun}]
    struct!(node, actions: new_actions)
  end

  @spec validate_set_default(t, Location.local_id()) :: {:ok, t} | :error
  def validate_set_default(%__MODULE__{default: default} = node, {_, _} = local_id) do
    case default do
      nil -> {:ok, struct!(node, default: local_id)}
      {_, _} = _preexisting_default -> :error
    end
  end

  #####################################
  # CONVERTERS

  @doc """
  return the first local id.

  Later, when I refactor node to hold only one local id,
  change the implementation.
  """
  @spec local_id(t) :: Location.local_id()
  def local_id(%__MODULE__{location: location}), do: Location.local_id(location)

  @spec actions(t, action_type()) :: [Statechart.action()]
  def actions(%__MODULE__{actions: actions}, action_type) do
    Enum.flat_map(actions, fn
      {^action_type, action_fn} -> [action_fn]
      _ -> []
    end)
  end

  @spec fetch_default(t()) :: {:ok, Location.local_id()} | :error
  def fetch_default(%__MODULE__{default: default}) do
    case default do
      {_, _} -> {:ok, default}
      nil -> :error
    end
  end

  for location_field <- ~w/module line/a do
    def unquote(location_field)(%__MODULE__{location: location}) do
      Location.unquote(location_field)(location)
    end
  end

  @spec match_name?(t, Statechart.state()) :: boolean
  def match_name?(%__MODULE__{name: node_name}, name), do: node_name == name

  @spec name(t) :: Statechart.state()
  def name(%__MODULE__{name: val}), do: val

  @spec transitions(t) :: [Transition.t()]
  def transitions(%__MODULE__{transitions: val}), do: val

  # def deprecated_id(node), do: id(node)

  def leaf?(node) do
    MPTreeNode.__leaf__?(node)
  end

  def local_root?(%__MODULE__{local_root?: val}), do: val

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    alias Statechart.Schema.Node

    def inspect(%Node{local_root?: true} = node, opts) do
      fields = standard_fields(node)
      Statechart.Util.Inspect.custom_kv("Root", fields, opts)
    end

    def inspect(node, opts) do
      fields = [name: node.name] ++ standard_fields(node)
      Statechart.Util.Inspect.custom_kv("Node", fields, opts)
    end

    defp standard_fields(%Node{transitions: t, actions: a, default: d} = node) do
      [
        # LATER make this part of the api
        {:lft_rgt, MPTreeNode.__lft_rgt__(node)},
        {:location, node.location},
        if(d, do: {:default, d}),
        unless(t == [], do: {:transitions, t}),
        unless(a == [], do: {:actions, a})
      ]
      |> Enum.filter(& &1)
    end
  end
end
