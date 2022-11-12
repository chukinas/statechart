defmodule Statechart.Schema.Tree do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Tree
    """

  alias Statechart.Schema.Node
  alias Statechart.Schema.Location

  #####################################
  # TYPES

  @type t :: MPTree.t()
  @type nodes :: [Node.t()]
  @type single_selector :: MPTree.match_fn() | :local | keyword()
  @type selector :: single_selector() | [single_selector()]

  #####################################
  # CONSTRUCTORS

  @spec new(Location.t()) :: t()
  def new(%Location{} = location) do
    location
    |> Node.root()
    |> MPTree.from_node()
  end

  #####################################
  # VALIDATING REDUCERS (return ok tuples or error atom)

  @spec validate_insert(t(), Node.t() | t(), selector()) :: {:ok, t()} | :error
  def validate_insert(tree, node_or_tree, selector) do
    with {:ok, match_fn} <- _to_match_fn(tree, selector) do
      MPTree.insert(tree, node_or_tree, match_fn)
    end
  end

  @spec validate_replace_node(t, Node.t()) :: {:ok, t()} | :error
  defp validate_replace_node(tree, node) do
    local_id = Node.local_id(node)
    update_fn = fn _node -> node end
    validate_update_node(tree, update_fn, local_id: local_id)
  end

  @spec validate_update_node(t, MPTree.update_fn(), selector()) :: {:ok, t()} | :error
  defp validate_update_node(tree, update_fn, selector) when is_function(update_fn, 1) do
    with {:ok, match_fn} <- _to_match_fn(tree, selector) do
      nodes = MPTree.nodes(tree)

      case Enum.filter(nodes, match_fn) do
        [_node] ->
          tree = MPTree.update_nodes(tree, update_fn, match_fn)
          {:ok, tree}

        _something_else ->
          :error
      end
    end
  end

  #####################################
  # REDUCERS

  @spec replace_node!(t, Node.t()) :: t()
  def replace_node!(tree, node) do
    {:ok, tree} = validate_replace_node(tree, node)
    tree
  end

  @spec update_node!(t, MPTree.update_fn(), selector()) :: t()
  def update_node!(tree, update_fn, selector) when is_function(update_fn, 1) do
    case validate_update_node(tree, update_fn, selector) do
      {:ok, tree} ->
        tree

      :error ->
        raise "Failed to update node, tree: #{inspect(tree)}, update_fn: #{inspect(update_fn)}"
    end
  end

  @spec update_nodes(t, MPTree.update_fn(), selector()) :: t()
  def update_nodes(tree, update_fn, selector) when is_function(update_fn, 1) do
    with {:ok, match_fn} <- _to_match_fn(tree, selector) do
      MPTree.update_nodes(tree, update_fn, match_fn)
    end
  end

  @spec update_root(t, MPTree.update_fn()) :: t
  def update_root(tree, update_fn) do
    [root | rest] = tree.nodes
    struct!(tree, nodes: [update_fn.(root) | rest])
  end

  #####################################
  # CONVERTERS

  for {mod_name, fn_name} <- [
        {MPTree, :fetch_descendents},
        {MPTree, :fetch_family_tree},
        {MPTree, :fetch_ancestors_and_self}
      ] do
    @spec unquote(fn_name)(t(), selector()) :: {:ok, nodes()} | :error
    def unquote(fn_name)(tree, selector) do
      with {:ok, match_fn} <- _to_match_fn(tree, selector) do
        unquote(mod_name).unquote(fn_name)(tree, match_fn)
      end
    end

    bang_fn_name = String.to_atom((fn_name |> to_string) <> "!")

    @spec unquote(bang_fn_name)(t(), selector()) :: nodes()
    def unquote(bang_fn_name)(tree, selector) do
      {:ok, nodes} = unquote(fn_name)(tree, selector)
      nodes
    end
  end

  @spec fetch_node(t(), selector()) :: {:ok, Node.t()} | :error
  def fetch_node(tree, selector) do
    with {:ok, match_fn} <- _to_match_fn(tree, selector) do
      MPTree.fetch_node(tree, match_fn)
    end
  end

  @spec fetch_node!(t(), selector()) :: Node.t()
  def fetch_node!(tree, match_fn) do
    case fetch_node(tree, match_fn) do
      {:ok, node} ->
        node

      :error ->
        raise "expected #{inspect(tree)} to have a single node matching #{inspect(match_fn)}, but didn't find any"
    end
  end

  # LATER I don't like the mismatch between :entry here and :enter in MPTree.
  @spec fetch_transition_path(t, selector, selector) ::
          {:ok, [{Node.action_type(), Node.t()}]} | :error
  def fetch_transition_path(tree, start_selector, end_selector) do
    with {:ok, start_match_fn} <- _to_match_fn(tree, start_selector),
         {:ok, end_match_fn} <- _to_match_fn(tree, end_selector) do
      MPTree.fetch_transition_path(tree, start_match_fn, end_match_fn)
      |> update_in([Access.elem(1), Access.all(), Access.elem(0)], fn
        :enter -> :entry
        :exit -> :exit
      end)
    end
  end

  @spec nodes(t) :: nodes()
  defdelegate nodes(tree), to: MPTree

  @spec fetch_nodes(t(), selector()) :: {:ok, nodes} | :error
  defp fetch_nodes(%MPTree{} = tree, selector) do
    with {:ok, match_fn} <- _to_match_fn(tree, selector) do
      matched_nodes = tree |> nodes |> Enum.filter(match_fn)
      {:ok, matched_nodes}
    end
  end

  @spec fetch_nodes!(t(), selector()) :: nodes
  def fetch_nodes!(%MPTree{} = tree, selector) do
    case fetch_nodes(tree, selector) do
      {:ok, nodes} -> nodes
      :error -> raise "whhops"
    end
  end

  @spec root(t) :: Node.t()
  def root(tree), do: MPTree.__root__(tree)

  #####################################
  # HELPERS

  @spec _to_match_fn(t(), selector()) :: {:ok, MPTree.match_fn()} | :error
  defp _to_match_fn(_tree, match_fn) when is_function(match_fn, 1), do: {:ok, match_fn}

  defp _to_match_fn(tree, selectors) when is_list(selectors) do
    is_local_fn =
      with do
        module = tree |> MPTree.__root__() |> Node.module()
        &(Node.module(&1) == module)
      end

    selectors
    |> Stream.map(&_match_fn_from_list_item(&1, is_local_fn))
    |> Enum.reduce_while(nil, fn
      :error, _ ->
        {:halt, :error}

      {:ok, match_fn}, nil ->
        {:cont, {:ok, match_fn}}

      {:ok, match_fn}, {:ok, reducer_match_fn} ->
        {:cont, {:ok, &(match_fn.(&1) && reducer_match_fn.(&1))}}
    end)
  end

  @spec _match_fn_from_list_item(term, MPTree.match_fn()) :: {:ok, MPTree.match_fn()} | :error
  defp _match_fn_from_list_item(item, is_local_fn) do
    case item do
      match_fn when is_function(match_fn) -> {:ok, match_fn}
      :local -> {:ok, is_local_fn}
      {:name, node_name} -> {:ok, &(Node.name(&1) == node_name)}
      {:local_id, local_id} -> {:ok, &(Node.local_id(&1) == local_id)}
      _ -> :error
    end
  end
end
