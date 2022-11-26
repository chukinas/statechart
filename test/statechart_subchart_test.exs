defmodule Statechart.SubchartTest do
  use Statechart.Case
  doctest Statechart

  describe "blarg" do
    test "`on :exit` is valid at root level of subchart" do
      statechart_test_module do
        subchart_new exit: &IO.inspect/1
      end
    end

    test "for a subchart root having actions declared at both the subchart and parent levels" do
      defmodule SubchartRootActionsBothLocalAndFromParent do
        use Statechart

        def action_entering_foo(_context), do: IO.puts("action declared by parent!")
        def action_entering_subchart(_context), do: IO.puts("action declared by subchart!")

        defmodule Subchart do
          statechart entry: &SubchartRootActionsBothLocalAndFromParent.action_entering_subchart/1
        end

        statechart default: :bar do
          :GOTO_FOO >>> :foo
          subchart :foo, Subchart, entry: &__MODULE__.action_entering_foo/1
          state :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          SubchartRootActionsBothLocalAndFromParent.new() |> Statechart.trigger(:GOTO_FOO)
        end)

      assert captured_io =~ "declared by subchart!"
      assert captured_io =~ "declared by parent!"
    end

    test "actions registered on a subchart's root persist after being inserted into a parent chart" do
      defmodule SubchartRootHasActions do
        use Statechart

        def action_entering_subchart(_context), do: IO.puts("entering subchart!")

        defmodule Subchart do
          statechart entry: &SubchartRootHasActions.action_entering_subchart/1
        end

        statechart default: :bar do
          :GOTO_FOO >>> :foo
          subchart :foo, Subchart
          state :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          SubchartRootHasActions.new() |> Statechart.trigger(:GOTO_FOO)
        end)

      assert captured_io =~ "entering subchart!"
    end
  end
end
