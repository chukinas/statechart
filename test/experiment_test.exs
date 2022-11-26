defmodule Statechart.Experiment1Test do
  use ExUnit.Case
  alias Statechart.Experiment, as: E

  test "baseline" do
    assert E.Baseline.result() == [8]
  end

  test "acc" do
    alias Statechart.Experiment.FunctionsAcc, as: A

    functions =
      A.start()
      |> A.push(fn x -> x + 3 end)
      |> A.push(&(&1 * 2))
      |> A.push(&List.wrap/1)
      |> A.get_and_stop()

    assert [8] == Enum.reduce(functions, 1, & &1.(&2))
  end

  test "dsl" do
    assert [8] = E.DSL.result()
  end

  test "use macros 1" do
    assert [8] = E.UseMacros1.result()
  end

  test "use macros 2" do
    # NOTE that this causes the functions list to be build up twice
    assert 1 = E.UseMacros2.result()
    assert 1 = E.UseMacros2.result()
  end

  test "before compile" do
    assert 1 = E.BeforeCompile.result()
    assert 1 = E.BeforeCompile.result()
  end

  # TODO need to stop the AccSchema Agent

  test "before compile full" do
    assert 4 = E.BeforeCompileFull.result()
  end

  test "named funs" do
    E.NamedFuns.unordered_funs()
    assert [8] = E.NamedFuns.result()
    assert [8] = E.NamedFuns.result()
  end

  test "attr" do
    assert E.Attrs.result() == [1]
  end
end
