defmodule Statechart.Build.MacroTransition do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.transition` macro.
    """

  require Statechart.Schema.Node, as: Node
  alias __MODULE__
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.MacroChart
  alias Statechart.Schema
  alias Statechart.Schema.Event
  alias Statechart.Schema.Location
  alias Statechart.Schema.Transition
  alias Statechart.Schema.Tree

  def build_ast(event, target_name) do
    quote bind_quoted: [event: event, target_name: target_name] do
      require MacroChart

      MacroChart.throw_if_not_in_statechart_block(
        "transition must be called inside a statechart/2 block"
      )

      MacroTransition.__do__(__ENV__, event, target_name)
    end
  end

  @spec __do__(Macro.Env.t(), Event.t(), Node.name()) :: :ok
  def __do__(env, event, target_name) do
    case AccStep.get(env) do
      :insert_transitions_and_defaults -> insert_transition(env, event, target_name)
      _ -> :ok
    end
  end

  @spec insert_transition(Macro.Env.t(), Event.t(), Node.name()) :: :ok
  defp insert_transition(env, event, target_name) do
    schema = AccSchema.get(env)
    tree = Schema.tree(schema)
    local_id = AccNodeStack.local_id(env)

    unless :ok == Event.validate(event) do
      raise StatechartError, "expect event to be an atom or module, got: #{inspect(event)}"
    end

    if transition = find_transition_in_family_tree(tree, local_id, event) do
      raise StatechartError,
            "events must be unique within a node and among its path and descendents, the event " <>
              inspect(event) <>
              " is already registered on line " <>
              inspect(Transition.line_number(transition))
    end

    target_local_id =
      case schema |> Schema.tree() |> Tree.fetch_node(name: target_name) do
        {:ok, node} ->
          Node.local_id(node)

        _ ->
          local_node_names =
            schema |> Schema.tree() |> Tree.fetch_nodes!([:local]) |> Enum.map(&Node.name/1)

          raise StatechartError,
                "Expected to find a target state with name :#{target_name} but none was found, " <>
                  "valid names are: #{inspect(local_node_names)}"
      end

    {module, parent_node_index} = AccNodeStack.local_id(env)
    transition = Transition.new(event, target_local_id, module, env.line, parent_node_index)

    new_tree = Tree.update_node!(tree, &Node.put_transition(&1, transition), local_id: local_id)
    AccSchema.put_tree(env, new_tree)
    :ok
  end

  @doc """
  Look for an event among a node's ancestors and path, which includes itself.
  """
  @spec find_transition_in_family_tree(Tree.t(), Location.local_id(), Event.t()) ::
          Transition.t() | nil
  def find_transition_in_family_tree(tree, local_id, event) do
    nodes = Tree.fetch_family_tree!(tree, local_id: local_id)

    nodes
    |> Stream.flat_map(&Node.transitions/1)
    |> Enum.find(&(Transition.event(&1) == event))
  end
end
