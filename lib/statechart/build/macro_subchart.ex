defmodule Statechart.Build.MacroSubchart do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.subchart` macro.
    """

  require Statechart.Schema.Node, as: Node
  alias __MODULE__
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroState
  alias Statechart.Build.MacroChart
  alias Statechart.Schema
  alias Statechart.Schema.Tree

  # LATER this is for the macro, currently dumbly called subchart_new,
  # that'll generate a partial statechart with no public API,
  # that'll be inserted into a statechart via the existing :state macro
  def new_ast(_opts, _block) do
    quote do
    end
  end

  def build_ast(name, module, opts, block) do
    quote do
      require MacroChart
      require AccNodeStack

      MacroChart.throw_if_not_in_statechart_block(
        "subchart must be called inside a statechart/2 block"
      )

      AccNodeStack.node_stack do
        MacroSubchart.__do__(
          __ENV__,
          unquote(name),
          unquote(module),
          unquote(opts |> Macro.escape())
        )

        unquote(block)
      end
    end
  end

  @spec __do__(Macro.Env.t(), Statechart.state(), module(), Keyword.t()) :: :ok
  def __do__(env, name, module, opts) do
    case AccStep.get(env) do
      :insert_nodes -> MacroState.insert_node(env, name, opts)
      :insert_subcharts -> insert_subchart(env, module)
      _ -> :ok
    end
  end

  # LATER test that calling state/1,2 inside subchart raises
  # A Subschema keeps its own root node.
  # That root node is the sole child of a new node in the parent schema.
  # That parent node has a local of the parent schema.
  # It has a default to the subschema root node
  defp insert_subchart(env, subchart_module) do
    local_id = AccNodeStack.local_id(env)
    schema = AccSchema.get(env)
    parent_node = schema |> Schema.tree() |> Tree.fetch_node!(local_id: local_id)

    subschema =
      try do
        %Schema{} = subchart_module.__schema__()
      rescue
        _ ->
          raise StatechartError,
                "the module #{subchart_module} on line #{env.line} does not " <>
                  "define a Statechart.Schema.t struct. See `use Statechart`"
      end

    parent_local_id = Node.local_id(parent_node)
    subchart_root_name = subchart_module
    tree = Schema.tree(schema)

    subtree = Schema.tree(subschema)

    {:ok, tree_with_inserted_subtree} =
      Tree.validate_insert(tree, subtree, local_id: parent_local_id)

    new_schema = Schema.put_tree(schema, tree_with_inserted_subtree)

    origin_node = Tree.fetch_node!(Schema.tree(new_schema), local_id: parent_local_id)
    new_schema = MacroState.insert_default(new_schema, origin_node, subchart_root_name)
    {:ok, new_schema}

    new_tree = Schema.tree(new_schema)

    AccSchema.put_tree(env, new_tree)

    :ok
  end
end
