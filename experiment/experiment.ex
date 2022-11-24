defmodule Statechart.Experiment.Baseline do
  @moduledoc "No metaprogramming; setting a baseline"

  @start_val 1

  @doc """
  Inspecting the function list reveals:
      [#Function<0.9006466/1 in Statechart.Experiment.Baseline.result/0>,
      #Function<1.9006466/1 in Statechart.Experiment.Baseline.result/0>,
      &List.wrap/1]
  """
  def result do
    [
      fn x -> x + 3 end,
      &(&1 * 2),
      &List.wrap/1
    ]
    |> Enum.reduce(@start_val, & &1.(&2))
  end
end

defmodule Statechart.Experiment.DSL do
  alias Statechart.Experiment.FunctionsAcc
  pid = FunctionsAcc.start()

  pid
  |> FunctionsAcc.push(fn x -> x + 3 end)
  |> FunctionsAcc.push(&(&1 * 2))
  |> FunctionsAcc.push(&List.wrap/1)

  functions = FunctionsAcc.get_and_stop(pid)
  result = Enum.reduce(functions, 1, & &1.(&2))

  def result do
    unquote(result)
  end
end

defmodule Statechart.Experiment.UseMacros1 do
  import Statechart.Experiment.Macros1
  do_all_the_things()

  def result do
    Enum.reduce(functions(), 1, & &1.(&2))
  end
end

defmodule Statechart.Experiment.UseMacros2 do
  import Statechart.Experiment.Macros2

  start do
  end
end

defmodule Statechart.Experiment.BeforeCompile do
  import __MODULE__.Macros

  start()
end

defmodule Statechart.Experiment.BeforeCompileFull do
  @moduledoc """
  This is finally the right solution.
  The functions need Macro.escape.
  I accumulate using an Agent whose pid is assigned to a module attr.
  In a before-compile callback then I grab the accumulate val from the Agent,
  then kill the agent and the module attr,
  then simply interpolate the finished data structure into an injected function.
  """
  import __MODULE__.Macros

  start do
    push_function(fn x -> x + 3 end)
    push_function(&(&1 * 2))
    push_function(&List.wrap/1)
  end
end

defmodule Statechart.Experiment.Attrs do
  @moduledoc """
  Only &Mod.fun/arity functions can be assigned to module attributes
  https://elixirforum.com/t/cannot-compile-attribute/21052/2
  """
  Module.register_attribute(__MODULE__, :functions, accumulate: true)
  @start_val 1
  # @functions fn x -> x + 3 end
  # @functions &(&1 * 2)
  @functions &List.wrap/1

  def result do
    @functions
    |> Enum.reduce(@start_val, & &1.(&2))
  end
end
