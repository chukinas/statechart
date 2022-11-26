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
    {:ok, pid} = Agent.start_link(fn -> [] end)
    :ok = Module.put_attribute(env.module, :__statechart_functions_pid__, pid)
    env
  end

  @spec put_and_get_placeholder(Macro.Env.t(), Macro.t()) :: placeholder
  def put_and_get_placeholder(env, function_ast) do
    fn_id = System.unique_integer()
    placeholder = {:__statechart_function__, fn_id}
    env |> pid |> Agent.update(&[{fn_id, function_ast} | &1])
    placeholder
  end

  #####################################
  # CONVERTERS

  defp pid(env) do
    Module.get_attribute(env.module, :__statechart_functions_pid__)
  end

  defp get_all(env) do
    env |> pid |> Agent.get(& &1)
  end

  @spec get_by_fn_id!(Macro.Env.t(), fn_id) :: fn_ast
  def get_by_fn_id!(env, fn_id) do
    case env
         |> get_all
         |> Enum.find_value(fn
           {^fn_id, fn_ast} -> fn_ast
           _ -> nil
         end) do
      nil ->
        raise "#{inspect(pid(env))} expected to find a fn assoc with #{fn_id} in #{inspect(get_all(env))}, but found none"

      fn_ast ->
        fn_ast
    end
  end

  # TODO Do I have to use Agent or can I just use mod attr?

  def stop(env) do
    env |> pid |> Agent.stop()
  end

  def prewalk_substitution_fn(env) do
    fn
      {:__statechart_function__, fn_id} -> get_by_fn_id!(env, fn_id)
      other -> other
    end
  end
end
