defmodule Statechart.Schema.TreeTest do
  use Statechart.Case

  test "single node smoke test" do
    # LATER ? add option to have the first node be the default
    statechart_test_module mod do
      statechart default: :blarg do
        state :blarg
      end
    end

    assert length(mod.__nodes__()) == 2
  end
end
