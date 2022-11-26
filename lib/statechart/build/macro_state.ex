defmodule Statechart.Build.MacroState do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.state` macro.
    """

  alias __MODULE__
  alias Statechart.Build.AccFunctions
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroChart
  alias Statechart.Build.MacroOpts
  alias Statechart.Schema
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  def build_ast(name, opts, block) do
    :ok = MacroOpts.validate_keys(opts, :state)

    quote do
      require MacroChart
      require AccNodeStack

      MacroChart.throw_if_not_in_statechart_block(
        "state/1 and state/2 must be called inside a statechart/2 block"
      )

      AccNodeStack.node_stack do
        # LATER focus these opts down
        MacroState.__do__(
          __ENV__,
          unquote(name),
          unquote(Keyword.take(opts, ~w/entry exit/a)),
          unquote(opts)
        )

        unquote(block)
      end
    end
  end

  @spec __do__(Macro.Env.t(), Statechart.state(), [Node.action_spec()], Keyword.t()) :: :ok
  # LATER make options specific
  def __do__(env, name, action_specs, opts) do
    case AccStep.get(env) do
      :insert_nodes ->
        insert_node(env, name, action_specs)

      :insert_transitions_and_defaults ->
        insert_default(env, opts)

      # LATER do validation stuff (like make sure all nodes get hit)
      :validate ->
        :ok

      _ ->
        :ok
    end

    :ok
  end

  @spec insert_node(Macro.Env.t(), Statechart.state(), [Node.action_spec()]) :: Macro.Env.t()
  def insert_node(env, name, action_specs) do
    schema = AccSchema.get(env)

    new_node =
      with do
        :ok = validate_name!(schema, name)
        location = AccNodeStack.location(env)

        Node.new(name, location)
      end

    # LATER take advantage of this in statechart?
    new_node =
      action_specs
      |> Keyword.take(~w/entry exit/a)
      |> Enum.reduce(new_node, fn {type, action}, node ->
        placeholder = AccFunctions.put_and_get_placeholder(env, action)
        Node.add_action(node, type, placeholder)
      end)

    new_tree =
      case Tree.validate_insert(schema.tree, new_node, local_id: AccNodeStack.parent_local_id(env)) do
        {:ok, tree} -> tree
        :error -> raise "id not found!"
      end

    AccSchema.put_tree(env, new_tree)
  end

  def insert_default(env, opts) do
    schema = AccSchema.get(env)
    tree = AccSchema.tree(env)
    local_id = AccNodeStack.local_id(env)
    origin_node = Tree.fetch_node!(tree, local_id: local_id)

    case Keyword.fetch(opts, :default) do
      {:ok, target_name} ->
        new_tree = schema |> insert_default(origin_node, target_name) |> Schema.tree()
        AccSchema.put_tree(env, new_tree)
        :ok

      # no default specified
      :error ->
        :ok
    end
  end

  # LATER I don't like that this is the same name
  @spec insert_default(Schema.t(), Node.t(), Statechart.state()) :: Schema.t()
  def insert_default(schema, origin_node, target_name) do
    if Node.leaf?(origin_node) do
      raise StatechartError, "cannot assign a default to a leaf node"
    end

    tree = Schema.tree(schema)

    target_local_id =
      case Tree.fetch_node(tree, name: target_name) do
        {:ok, node} -> Node.local_id(node)
        :error -> raise StatechartError, "There is no node with name of #{inspect(target_name)}"
      end

    # validate_target_id_is_descendent
    with origin_local_id = Node.local_id(origin_node),
         tree = Schema.tree(schema),
         {:ok, descendents} <- Tree.fetch_descendents(tree, local_id: origin_local_id),
         true <- target_local_id in Stream.map(descendents, &Node.local_id/1) do
      :ok
    else
      _ ->
        raise StatechartError, "default node must be a descendent"
    end

    new_origin_node =
      case Node.validate_set_default(origin_node, target_local_id) do
        {:ok, node} -> node
        :error -> raise StatechartError, "This node already has a default!"
      end

    new_tree =
      schema
      |> Schema.tree()
      |> Tree.replace_node!(new_origin_node)

    Schema.put_tree(schema, new_tree)
  end

  @spec validate_name!(Schema.t(), Statechart.state()) :: :ok | no_return
  defp validate_name!(schema, name) do
    case schema |> Schema.tree() |> Tree.fetch_node([:local, name: name]) do
      {:ok, node_with_same_name} ->
        raise StatechartError,
              "a state with name #{inspect(name)} was already defined on line #{Node.line(node_with_same_name)}"

      _ ->
        :ok
    end

    :ok
  end
end
