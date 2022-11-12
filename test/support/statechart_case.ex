defmodule Statechart.Case do
  # TODO make sure not part of docs

  use ExUnit.CaseTemplate

  defmacro module_name do
    quote do
      String.to_atom("TestStatechart#{__ENV__.line}")
    end
  end

  defmacro statechart_test_module(name \\ nil, do: block) do
    named_module_ast =
      quote do
        {:module, name, _, _} =
          defmodule String.to_atom("TestStatechart#{__ENV__.line}") do
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
    end
  end
end
