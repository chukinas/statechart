defmodule StatechartTest do
  use Statechart.Case
  use Statechart
  alias Statechart.Schema
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree
  doctest Statechart

  test "single node smoke test" do
    # LATER ? add option to have the first node be the default
    statechart_test_module mod do
      statechart default: :blarg do
        state :blarg
      end
    end

    assert length(mod.__nodes__()) == 2
  end

  describe "statechart/2" do
    test "create a statechart within a submodule" do
      statechart module: module_name() do
        nil
      end
    end

    test "raises if statechart was already called in this module" do
      assert_raise StatechartError, ~r/Only one statechart/, fn ->
        statechart_test_module do
          statechart do: nil
          statechart do: nil
        end
      end
    end

    test "raises if no default is set and at least one state was declared" do
      assert_raise StatechartError, ~r/need to set a default state/, fn ->
        statechart module: NoDefaultSet do
          # LATER should I allow no do block?
          state :foo, do: nil
        end
      end
    end

    # LATER add statechart/0 to API
    test "statechart/0 succeeds" do
      statechart_test_module do
        statechart()
      end
    end

    test "does not raise if no default is set and if there are no states declared" do
      statechart_test_module do
        statechart do: nil
      end
    end
  end

  describe "state macro" do
    test "raises if called before statechart block" do
      assert_raise StatechartError, ~r/must be called inside/, fn ->
        defmodule StateOutOfScopeBefore do
          import Statechart
          state :naughty
        end
      end
    end

    test "raises if called after a statechart block" do
      assert_raise StatechartError, ~r/must be called inside/, fn ->
        defmodule StateOutOfScopeAfter do
          use Statechart

          statechart do
          end

          import Statechart
          state :naughty
        end
      end
    end

    test "raises if default opt if given to a leaf node" do
      assert_raise StatechartError, ~r/cannot assign a default to a leaf/, fn ->
        defmodule DefaultPassedToLeafNode do
          use Statechart

          statechart do
            state :a, default: :b do
            end

            state :b
          end
        end
      end
    end

    test "raises if default target is not a descendent" do
      assert_raise StatechartError, ~r/must be a descendent/, fn ->
        defmodule DefaultIsNotDescendent do
          use Statechart

          statechart do
            state :a, default: :b do
              state :c
            end

            state :b
          end
        end
      end
    end

    test "state/1 accepts just the state name" do
      statechart_test_module mod do
        statechart default: :alpaca do
          state :alpaca
        end
      end

      assert [:alpaca] == mod.new |> Statechart.states()
    end

    test "state/2 arg2 accepts a do-block" do
      statechart_test_module mod do
        statechart default: :child_state do
          state :parent_state do
            state :child_state
          end
        end
      end

      assert [:parent_state, :child_state] == mod.new |> Statechart.states()
    end

    test "state/2 arg2 accepts an opts list" do
      statechart_test_module mod do
        statechart default: :alpaca do
          state :alpaca, entry: &List.wrap/1
        end
      end

      assert [] == mod.new |> Statechart.context()
    end

    test "state will throw if opts contain invalid keys" do
      assert_raise ArgumentError, ~r/Allowed opts for state are/, fn ->
        statechart_test_module do
          statechart default: :battlestar do
            state :alpaca, invalid_key: :blarg
          end
        end
      end
    end

    test "correctly nests states" do
      defmodule Sample do
        use Statechart

        statechart default: :d do
          state :a do
            state :b do
              :GOTO_D >>> :d

              state :c do
                state :d do
                end
              end
            end
          end
        end
      end

      schema = Sample.__schema__()
      tree = Schema.tree(schema)
      {Sample, 5} = d_node_local_id = tree |> Tree.fetch_node!(name: :d) |> Node.local_id()
      {:ok, d_path} = Tree.fetch_ancestors_and_self(tree, local_id: d_node_local_id)
      assert length(d_path) == 5
      d_path_as_atoms = Enum.map(d_path, &Node.name/1)
      assert d_path_as_atoms == [Sample | ~w/a b c d/a]
    end

    test "raises on duplicate **local** state name" do
      assert_raise StatechartError, ~r/was already defined on line /, fn ->
        defmodule DuplicateLocalNodeName do
          use Statechart

          statechart do
            state :on
            state :on
          end
        end
      end
    end
  end

  # This should test for the line number
  # Should give suggestions for matching names ("Did you mean ...?")
  describe ">>>/2" do
    test "an event targetting a branch node must provides a default path to a leaf node"

    test "raises if event targets a root that doesn't resolve"
    # This should test for the line number
    test "raises a StatechartError on invalid event names"
    test "raises if target does not resolve to a leaf node"
    test "raises if target does not exist"

    test "raises if one of node's ancestors already has a transition with this event" do
      assert_raise StatechartError, ~r/events must be unique/, fn ->
        defmodule MyStatechart do
          use Statechart

          statechart do
            :AMBIGUOUS_EVENT >>> :b

            state :a do
              :AMBIGUOUS_EVENT >>> :c
            end

            state :b
            state :c
          end
        end
      end
    end
  end

  describe "ACTIONS & CONTEXT" do
    test "default context is `nil`" do
      defmodule Statechart4 do
        statechart do: nil
      end

      assert nil == Statechart4.new() |> Statechart.context()
    end

    test "statechart/2 :context key determines the starting context" do
      statechart_test_module mod do
        statechart context: {term, 42}
      end

      assert 42 == mod.new() |> Statechart.context()
    end

    # TODO move to support
    defmacrop assert_context(statechart, pattern) do
      quote do
        assert unquote(pattern) = unquote(statechart) |> Statechart.context()
      end
    end

    test "`on :entry` works at root level" do
      statechart_test_module mod do
        statechart entry: &List.wrap/1
      end

      assert_context(mod.new(), [])
    end

    test "statechart/1 raises ArgumentError if passed an :exit opt" do
      assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
        statechart_test_module do
          statechart exit: &List.wrap/1
        end
      end
    end

    test "statechart/2 raises ArgumentError if passed an :exit opt" do
      assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
        statechart_test_module do
          statechart exit: &List.wrap/1 do
            state :alpaca
          end
        end
      end
    end

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

    test "exit & entry actions fire" do
      defmodule OnExitEnterTest do
        use Statechart

        def action_put_a(_context), do: IO.puts("put a")
        def action_put_b(_context), do: IO.puts("put b")

        statechart default: :a do
          :GOTO_B >>> :b
          state :a, exit: &__MODULE__.action_put_a/1
          state :b, entry: &__MODULE__.action_put_b/1
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn -> OnExitEnterTest.new() |> Statechart.trigger(:GOTO_B) end)

      assert captured_io =~ "put a"
      assert captured_io =~ "put b"
    end
  end
end
