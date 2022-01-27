defmodule Statechart.FutureFeature.SubchartTest do
  use ExUnit.Case
  use Statechart
  alias Statechart.Schema
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  defmodule SubChart do
    statechart default: :on do
      state :on
      state :off
    end
  end

  describe "subchart/2" do
    test "successfully inserts a sub-chart into a parent chart" do
      defmodule MainChart do
        use Statechart

        statechart default: :flarb do
          state :flarb
          subchart :flazzl, SubChart
        end
      end

      schema = MainChart.__schema__()
      assert length(Schema.tree(schema) |> Tree.nodes()) == 6

      assert {MainChart, 3} =
               schema |> Schema.tree() |> Tree.fetch_node!(name: :flazzl) |> Node.local_id()
    end

    test "throws if subchart is anything other than a module that defines a Statechart" do
      assert_raise StatechartError, ~r/does not define a Statechart/, fn ->
        statechart module: HasBadSubchartArg do
          subchart :flazzl, "hi"
        end
      end
    end
  end
end
