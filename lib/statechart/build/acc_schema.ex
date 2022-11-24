defmodule Statechart.Build.AccSchema do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Accumulator that holds the current schema
    """

  alias Statechart.Schema
  alias Statechart.Schema.Tree

  #####################################
  # REDUCERS

  # TODO remove the __statechart_schema__

  @spec init(Macro.Env.t(), Schema.t()) :: Macro.Env.t()
  def init(env, %Schema{} = schema) do
    {:ok, pid} = Agent.start_link(fn -> schema end)
    :ok = Module.put_attribute(env.module, :__statechart_schema_pid__, pid)
    :ok = Module.put_attribute(env.module, :__statechart_schema__, schema)
    env
  end

  @spec update_tree(Macro.Env.t(), (Tree.t() -> Tree.t())) :: Macro.Env.t()
  def update_tree(env, tree_update_fn) do
    new_tree = env |> tree() |> tree_update_fn.()
    put_tree(env, new_tree)
  end

  @spec put_tree(Macro.Env.t(), Tree.t()) :: Macro.Env.t()
  def put_tree(env, %MPTree{} = tree) do
    new_schema = env |> get |> Schema.put_tree(tree)
    env |> pid |> Agent.update(fn _ -> new_schema end)
    :ok = Module.put_attribute(env.module, :__statechart_schema__, new_schema)
    env
  end

  #####################################
  # CONVERTERS

  defp pid(env) do
    Module.get_attribute(env.module, :__statechart_schema_pid__)
  end

  @spec get(Macro.Env.t()) :: Schema.t()
  def get(env) do
    %Schema{} = Module.get_attribute(env.module, :__statechart_schema__)
    %Schema{} = env |> pid |> Agent.get(& &1)
  end

  @spec tree(Macro.Env.t()) :: Tree.t()
  def tree(env) do
    env |> get |> Schema.tree()
  end
end
