defmodule Statechart.Build.MacroOnEnterExit do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.on` macro.
    """

  alias __MODULE__
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.MacroStatechart
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  def build_ast(action_type, action_fn) do
    quote bind_quoted: [action_type: action_type, action_fn: action_fn] do
      require MacroStatechart

      # LATER test this behavior
      MacroStatechart.throw_if_not_in_statechart_block(
        "'on' must be called inside a statechart/2 block"
      )

      :ok = MacroOnEnterExit.__do__(__ENV__, action_type, action_fn)
    end
  end

  @spec __do__(Macro.Env.t(), Node.action_type(), Node.action_fn()) :: :ok
  def __do__(env, action_type, action_fn) do
    case AccStep.get(env) do
      :insert_actions -> insert_action(env, action_type, action_fn)
      _ -> :ok
    end
  end

  @spec insert_action(Macro.Env.t(), Node.action_type(), Node.action_fn()) :: :ok
  def insert_action(env, action_type, action_fn) do
    update_node_fn = fn node ->
      case Node.validate_add_action(node, action_type, action_fn) do
        {:ok, node} ->
          node

        :error ->
          raise StatechartError,
                "the on/1 macro expects a single-item keyword list with a " <>
                  "key of either :enter or :exit, got: #{inspect(action_type)}"
      end
    end

    AccSchema.update_tree(env, fn tree ->
      local_id = AccNodeStack.local_id(env)
      Tree.update_node!(tree, update_node_fn, local_id: local_id)
    end)

    :ok
  end
end
