defmodule Statechart.Build.AccFunctions do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Instead of storing actions directly in the `t:Statechart.Schema/0`
    during the build, we store their ASTs here.

    This is because in order to inject the completed schema into the caller,
    we need to escape that data structure. But if that data structure contains
    functions not in the form &Mod.fun/arity, they cannot be escaped.

    So we store their ASTs in this accumulator and then walk the escaped schema's AST,
    replacing the placeholders with the function ASTs. At that point, the now-fully-complete
    schema AST can be injected into the caller.

    If there is a better way to do this, please let me know.
    But it does seem to work just fine.
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

  @doc """
  Returns an anonymous function that can be passed to the prewalk of the schema's AST,
  replacing placeholders with the appropriate function AST.
  """
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
