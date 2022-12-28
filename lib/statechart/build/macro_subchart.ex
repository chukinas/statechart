defmodule Statechart.Build.MacroSubchart do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.subchart` macro.
    """

  use TypedStruct
  alias Statechart.Build.AccFunctions
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroState
  alias Statechart.Schema
  alias Statechart.Schema.Tree

  typedstruct do
    field :module, module
    field :connections, %{atom => atom}
  end

  @spec build_definition(module, list()) :: t()
  def build_definition(module, connections \\ []) when is_list(connections) do
    connections_as_map =
      Enum.reduce(connections, %{}, fn
        state_name, connections when is_atom(state_name) ->
          Map.put(connections, state_name, state_name)

        {state_name, target_name}, connections
        when is_atom(state_name) and is_atom(target_name) ->
          Map.put(connections, state_name, target_name)

        keyword_list, connections when is_list(keyword_list) ->
          Map.merge(connections, Map.new(keyword_list))
      end)

    %__MODULE__{module: module, connections: connections_as_map}
  end

  def __from_keyword_value__(env, subchart_module) do
    case AccStep.get(env) do
      :insert_subcharts -> __do_from_keyword_value__(env, subchart_module)
      _ -> :ok
    end
  end

  # LATER test that calling state/1,2 inside subchart raises
  # A Subschema keeps its own root node.
  # That root node is the sole child of a new node in the parent schema.
  # That parent node has a local of the parent schema.
  # It has a default to the subschema root node
  defp __do_from_keyword_value__(env, subchart_module) do
    unless is_atom(subchart_module) do
      raise(
        ArgumentError,
        "Invalid value given to the :subchart key in #{env.module}, line #{env.line}. " <>
          "Expected a module, got: #{inspect(subchart_module)}"
      )
    end

    local_id = AccNodeStack.local_id(env)
    parent_schema = AccSchema.get(env)

    subchart_module.__function_asts__() |> Enum.each(&AccFunctions.add_function(env, &1))

    schema_with_inserted_subchart =
      with do
        parent_tree = Schema.tree(parent_schema)
        subchart_schema = %Schema{} = subchart_module.__schema_with_placeholders__()
        subchart_tree = Schema.tree(subchart_schema)

        {:ok, tree_with_inserted_subtree} =
          Tree.validate_insert(parent_tree, subchart_tree, local_id: local_id)

        Schema.put_tree(parent_schema, tree_with_inserted_subtree)
      end

    schema_with_default_from_parent_node_to_subchart =
      with do
        origin_node =
          schema_with_inserted_subchart
          |> Schema.tree()
          |> Tree.fetch_node!(local_id: local_id)

        subchart_root_name = subchart_module
        MacroState.insert_default(schema_with_inserted_subchart, origin_node, subchart_root_name)
      end

    AccSchema.put(env, schema_with_default_from_parent_node_to_subchart)
    :ok
  end

  def subchart_api_ast(escaped_schema_with_placeholders) do
    quote do
      def __schema_with_placeholders__, do: unquote(escaped_schema_with_placeholders)

      def __function_asts__ do
        # TODO this implementation details belongs in AccFunctions
        @__statechart_functions__
      end
    end
  end
end
