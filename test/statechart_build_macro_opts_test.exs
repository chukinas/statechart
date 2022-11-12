defmodule Statechart.Build.MacroOptsTest do
  use ExUnit.Case
  alias Statechart.Build.MacroOpts

  test "validations keys are the same as the doc keys" do
    # Enforces that docs get added when new opts are added.
    validation_keys =
      MacroOpts.__validation_keys__()
      |> Map.values()
      |> Stream.concat()
      |> Stream.uniq()
      |> Enum.sort()

    doc_keys = MacroOpts.__doc_keys__() |> Map.keys() |> Enum.sort()

    assert validation_keys == doc_keys
  end
end
