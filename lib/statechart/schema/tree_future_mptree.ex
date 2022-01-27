defmodule Statechart.Schema.FutureMPTree do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Future These are functions to be extracted to MPTree
    """

  alias MPTree.Node, as: MPTreeNode

  @type t :: MPTree.t()
  @type nodes :: [MPTreeNode.t()]
  @type action_type :: :exit | :enter

  @typedoc """
  To travel from one node to another, you have to travel up the origin node's path
  and then down the target node's path. This type describes that path.
  You rarely ever go all the way up to the root node. Instead, you travel up to where
  the two paths meet.

  This is important for handling the exit/enter actions for each node along this path.

  CONSIDER: come up with a better term for it? One that doesn't use the word `path`?
  """
  @type transition_path :: [{action_type, MPTreeNode.t()}]

  @spec fetch_family_tree(t(), MPTree.match_fn()) :: {:ok, nodes()} | :error
  def fetch_family_tree(tree, match_fn) do
    with {:ok, path} <- fetch_root_to_self(tree, match_fn),
         {:ok, descendents} <- MPTree.fetch_descendents(tree, match_fn) do
      {:ok, path ++ descendents}
    end
  end

  @spec fetch_node(t(), MPTree.match_fn()) :: {:ok, MPTreeNode.t()} | :error
  def fetch_node(tree, match_fn) do
    with node when not is_nil(node) <- tree |> MPTree.nodes() |> Enum.find(match_fn) do
      {:ok, node}
    else
      _ -> :error
    end
  end

  @spec fetch_root_to_self(t, MPTree.match_fn()) :: {:ok, nodes()} | :error
  def fetch_root_to_self(tree, match_fn) do
    with {:ok, node} <- fetch_node(tree, match_fn) do
      ancestors =
        tree
        |> MPTree.nodes()
        |> Enum.filter(&MPTreeNode.__ancestor_and_descendent__?(&1, node))

      {:ok, ancestors ++ [node]}
    end
  end

  # LATER right now there are two meanings to the word "path" in this library
  #      The first is the "path" from root to node.
  #      The second is the "path" up towards the root from one node and back down to another node
  #      I should really clarify my language around this.
  @spec fetch_transition_path(t(), MPTree.match_fn(), MPTree.match_fn()) ::
          {:ok, transition_path()} | :error
  def fetch_transition_path(tree, start_node_selector, end_node_selector) do
    with {:ok, up_path} <- fetch_root_to_self(tree, start_node_selector),
         {:ok, down_path} <- fetch_root_to_self(tree, end_node_selector) do
      path = do_transition_path(up_path, down_path)
      {:ok, path}
    end
  end

  @spec do_transition_path(nodes(), nodes()) :: transition_path()
  defp do_transition_path([head1, head2 | state_tail], [head1, head2 | destination_tail]) do
    do_transition_path([head2 | state_tail], [head2 | destination_tail])
  end

  defp do_transition_path([head1 | state_tail], [head1 | destination_tail]) do
    state_path_items = Stream.map(state_tail, &{:exit, &1})
    destination_path_items = Enum.map(destination_tail, &{:enter, &1})
    Enum.reduce(state_path_items, destination_path_items, &[&1 | &2])
  end
end
