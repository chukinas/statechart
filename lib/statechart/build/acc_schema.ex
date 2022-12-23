defmodule Statechart.Build.AccSchema do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Accumulator that holds the current schema
    """

  alias Statechart.Schema
  alias Statechart.Schema.Tree

  #####################################
  # REDUCERS

  @spec init(Macro.Env.t(), Schema.t()) :: Macro.Env.t()
  def init(env, %Schema{} = schema) do
    :ok = Module.put_attribute(env.module, :__statechart_schema__, schema)
    env
  end

  @spec put(Macro.Env.t(), Schema.t()) :: Macro.Env.t()
  def put(env, schema) do
    Module.put_attribute(env.module, :__statechart_schema__, schema)
    env
  end

  @spec update_schema(Macro.Env.t(), (Schema.t() -> Schema.t())) :: Macro.Env.t()
  def update_schema(env, schema_update_fn) do
    new_schema = env |> get |> schema_update_fn.()
    put(env, new_schema)
  end

  @spec put_tree(Macro.Env.t(), Tree.t()) :: Macro.Env.t()
  def put_tree(env, %MPTree{} = tree) do
    new_schema = env |> get |> Schema.put_tree(tree)
    put(env, new_schema)
  end

  #####################################
  # CONVERTERS

  @spec get(Macro.Env.t()) :: Schema.t()
  def get(env) do
    Module.get_attribute(env.module, :__statechart_schema__)
  end

  @spec tree(Macro.Env.t()) :: Tree.t()
  def tree(env) do
    env |> get |> Schema.tree()
  end
end
