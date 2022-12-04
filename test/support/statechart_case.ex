defmodule Statechart.Case do
  use ExUnit.CaseTemplate

  # LATER maybe these two clauses should be separate macros/functions
  defmacro assert_context(statechart, nil) do
    quote do
      assert nil == unquote(statechart) |> Statechart.context()
    end
  end

  defmacro assert_context(statechart, pattern) do
    quote do
      assert unquote(pattern) = unquote(statechart) |> Statechart.context()
    end
  end

  def assert_state(machine, expected_state) do
    assert Statechart.in_state?(machine, expected_state)
    machine
  end

  defmacro module_name do
    quote do
      String.to_atom("TestStatechart#{__ENV__.line}")
    end
  end

  defmacro statechart_test_module(name \\ nil, do: block) do
    named_module_ast =
      quote do
        {:module, name, _, _} =
          defmodule String.to_atom("#{__MODULE__}_#{__ENV__.line}") do
            unquote(block)
          end

        name
      end

    if name do
      quote do
        unquote(named_module_ast)
        var!(unquote(name)) = name
      end
    else
      named_module_ast
    end
  end

  using do
    quote do
      import Statechart.Case
      use Statechart
    end
  end
end
