defmodule Statechart.StatechartTest do
  use Statechart.Case
  doctest Statechart

  # LATER add statechart/0 to API
  test "Statechart.statechart/0 exists to allow the creation of placeholders" do
    statechart_test_module do: statechart()
  end

  test "Statechart.statechart/X raises if already called in this module" do
    assert_raise StatechartError, ~r/Only one statechart/, fn ->
      statechart_test_module do
        statechart()
        statechart()
      end
    end
  end

  describe "Statechart.statechart/X :default option" do
    test "is required if any states are declared" do
      assert_raise StatechartError, ~r/need to set a default state/, fn ->
        statechart module: NoDefaultSet do
          # LATER should I allow no do block?
          state :foo, do: nil
        end
      end
    end

    test "is optional if no states are declared" do
      statechart_test_module do
        statechart do: nil
      end
    end
  end

  test "Statechart.statechart/X :module option wraps chart in the given module" do
    statechart module: module_name()
  end

  # This should test for the line number
  # Should give suggestions for matching names ("Did you mean ...?")
  describe ">>>/2" do
    # This should test for the line number
    test "raises a StatechartError on invalid event names"
    test "an event targetting a branch node must provides a default path to a leaf node"
    test "raises if event targets a root that doesn't resolve"
    test "raises if target does not resolve to a leaf node"
    test "raises if target does not exist"
  end

  describe "Statechart.statechart/X :context option" do
    test "is optional, in which case the context defaults to `nil`" do
      statechart_test_module mod do
        statechart do: nil
      end

      mod.new() |> assert_context(nil)
    end

    test "determines the starting context" do
      statechart_test_module mod do
        statechart context: {term, 42}
      end

      mod.new() |> assert_context(42)
    end
  end

  describe "Statechart.statechart/X :entry option" do
    test "transforms the context when machine is instantiated" do
      statechart_test_module mod do
        statechart entry: &List.wrap/1
      end

      mod.new() |> assert_context([])
    end

    test "can take the form &Mod.fun/arity" do
      statechart_test_module mod do
        statechart entry: &List.wrap/1
      end

      mod.new() |> assert_context([])
    end

    # TODO reimplement
    # test "can take the form &(&1 + 1)" do
    #   defmodule BlargMaster do
    #     statechart context: {integer, 0},
    #                # entry: &List.wrap/1,
    #                # entry: &(1 + &1),
    #                # entry: &(&1 / 1),
    #                entry: fn int -> int + 1 end
    #   end

    #   BlargMaster.new() |> assert_context([])
    # end
  end

  test "Statechart.statechart/1 :exit option raises" do
    assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
      statechart_test_module do
        statechart exit: &List.wrap/1
      end
    end
  end

  test "Statechart.statechart/2 :exit option raises" do
    assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
      statechart_test_module do
        statechart exit: &List.wrap/1 do
          state :alpaca
        end
      end
    end
  end
end
