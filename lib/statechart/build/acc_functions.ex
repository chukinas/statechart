defmodule Statechart.Build.AccFunctions do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Instead of storing actions in the `t:Statechart.Schema/0`
    during the build, we store their ASTs here.

    At the before_compile step, we walk the AST,
    replacing the action placeholders with the correct action AST.
    """

  @type fn_ast :: Macro.t()
  @type fn_id :: integer
  @type placeholder :: {:__statechart_function__, fn_id}

  #####################################
  # REDUCERS

  @spec init(Macro.Env.t()) :: Macro.Env.t()
  def init(env) do
    :ok = Module.register_attribute(env.module, :__statechart_functions__, accumulate: true)
    env
  end

  @spec put_and_get_placeholder(Macro.Env.t(), Macro.t()) :: placeholder
  def put_and_get_placeholder(env, {_, _, _} = function_ast) do
    fn_id = System.unique_integer()
    placeholder = {:__statechart_function__, fn_id}
    Module.put_attribute(env.module, :__statechart_functions__, {fn_id, function_ast})
    placeholder
  end

  #####################################
  # CONVERTERS

  def prewalk_substitution_fn(%Macro.Env{module: module}) do
    fn
      {:__statechart_function__, fn_id} ->
        module
        |> Module.get_attribute(:__statechart_functions__)
        |> Enum.find_value(fn
          {^fn_id, fn_ast} -> fn_ast
          _ -> nil
        end)

      other ->
        other
    end
  end
end
