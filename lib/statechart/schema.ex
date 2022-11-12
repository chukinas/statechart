defmodule Statechart.Schema do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Definitions
    - SCHEMA: (this module) a tree of nodes defined by the statechart macro
    - LOCAL NODE: A node that was defined in the same module as the schema itself
      Non-Local Nodes are ones defined in another module and inserted into this schema as a subchart
    """

  use TypedStruct
  alias Statechart.Schema.Event
  alias Statechart.Schema.Location
  alias Statechart.Schema.Node
  alias Statechart.Schema.Transition
  alias Statechart.Schema.Tree

  #####################################
  # TYPES

  typedstruct enforce: true do
    field :tree, Tree.t()
  end

  #####################################
  # CONSTRUCTORS

  def from_tree(tree) do
    %__MODULE__{tree: tree}
  end

  #####################################
  # REDUCERS

  def put_tree(schema, tree) do
    %__MODULE__{schema | tree: tree}
  end

  #####################################
  # CONVERTERS

  @spec destination_local_id_from_event(t, Event.t(), Location.local_id()) ::
          {:ok, Location.local_id()} | :error
  def destination_local_id_from_event(%__MODULE__{tree: tree} = schema, event, current_local_id) do
    origin_local_id =
      tree
      |> Tree.fetch_node!(local_id: current_local_id)
      |> Node.local_id()

    with {:ok, transition} <- fetch_transition(schema, origin_local_id, event),
         target_local_id = Transition.target_local_id(transition),
         {:ok, target_node} <- Tree.fetch_node(tree, local_id: target_local_id),
         {:ok, destination_node} <- resolve_to_leaf_node(schema, target_node),
         destination_local_id = Node.local_id(destination_node) do
      {:ok, destination_local_id}
    end
  end

  @spec fetch_actions(t, Tree.selector(), Tree.selector()) :: {:ok, [Node.action_fn()]} | :error
  def fetch_actions(schema, start_node_selector, end_node_selector) do
    case schema
         |> tree
         |> Tree.fetch_transition_path(start_node_selector, end_node_selector) do
      {:ok, transition_path} ->
        actions =
          Enum.flat_map(transition_path, fn {action_type, node} ->
            Node.actions(node, action_type)
          end)

        {:ok, actions}

      :error ->
        :error
    end
  end

  @doc """
  Searches through a node's `t:Statechart.Tree.Tree.path/0` for a Transition matching the given Event.
  """
  @spec fetch_transition(t, Location.local_id(), Event.t()) :: {:ok, Transition.t()} | :error
  def fetch_transition(schema, local_id_or_node_id, event) do
    selector =
      case local_id_or_node_id do
        {_module, _node_index} -> [local_id: local_id_or_node_id]
        _ -> [id: local_id_or_node_id]
      end

    tree = tree(schema)

    with {:ok, nodes} <- Tree.fetch_ancestors_and_self(tree, selector),
         {:ok, transition} <- fetch_transition_from_nodes(nodes, event) do
      {:ok, transition}
    end
  end

  @doc """
  Events can target branch nodes, but these nodes must resolve to a leaf node
  """
  @spec resolve_to_leaf_node(t, Node.t()) :: {:ok, Node.t()} | :error
  def resolve_to_leaf_node(%__MODULE__{} = schema, %Node{} = node) do
    with false <- Node.leaf?(node),
         {:ok, destination_local_id} <- Node.fetch_default(node),
         tree = tree(schema),
         {:ok, destination_node} <- Tree.fetch_node(tree, local_id: destination_local_id) do
      resolve_to_leaf_node(schema, destination_node)
    else
      true -> {:ok, node}
      :error -> :error
    end
  end

  @spec tree(t) :: Tree.t()
  def tree(%__MODULE__{tree: val}), do: val

  @spec starting_local_id(t) :: Location.local_id()
  def starting_local_id(%__MODULE__{} = schema) do
    {:ok, start_node} = fetch_start_node(schema)
    Node.local_id(start_node)
  end

  @spec fetch_start_node(t) :: {:ok, Node.t()} | :error
  def fetch_start_node(%__MODULE__{tree: tree} = schema) do
    root_node = Tree.root(tree)
    resolve_to_leaf_node(schema, root_node)
  end

  #####################################
  # HELPERS

  @spec fetch_transition_from_nodes([Node.t()], Event.t()) ::
          {:ok, Transition.t()} | {:error, :event_not_found}
  defp fetch_transition_from_nodes(nodes, event) do
    nodes
    |> Stream.flat_map(&Node.transitions/1)
    |> Enum.reverse()
    |> Enum.find(&(&1 |> Transition.event() |> Event.match?(event)))
    |> case do
      nil -> {:error, :event_not_found}
      transition -> {:ok, transition}
    end
  end
end
