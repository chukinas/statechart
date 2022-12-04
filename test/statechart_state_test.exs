defmodule Statechart.StateTest do
  # Tests for Statechart.state/2

  use Statechart.Case
  alias Statechart.Schema
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  describe "Statechart.state/X name (arg1)" do
    test "accepts an atom" do
      statechart_test_module mod do
        statechart default: :alpaca do
          state :alpaca
        end
      end

      mod.new |> assert_state(:alpaca)
    end

    # LATER test for the case where a subchart uses the same name (it should pass)
    test "raises on duplicate local name" do
      assert_raise StatechartError, ~r/was already defined on line /, fn ->
        statechart_test_module do
          statechart do
            state :on
            state :on
          end
        end
      end
    end
  end

  describe "Statechart.state/2 raises if called outside a statechart block" do
    test "(before)" do
      assert_raise StatechartError, ~r/must be called inside/, fn ->
        statechart_test_module do
          import Statechart
          state :before_statechart
          statechart()
        end
      end
    end

    test "(after)" do
      assert_raise StatechartError, ~r/must be called inside/, fn ->
        statechart_test_module do
          statechart()

          import Statechart
          state :after_statechart
        end
      end
    end
  end

  # LATER this will become an option
  test "Statechart.state/X :event option raises if one of node's ancestors already has a transition with this event" do
    assert_raise StatechartError, ~r/events must be unique/, fn ->
      defmodule MyStatechart do
        use Statechart

        statechart event: :AMBIGUOUS_EVENT >>> :b do
          state :a, event: :AMBIGUOUS_EVENT >>> :c
          state :b
          state :c
        end
      end
    end
  end

  describe "Statechart.state/X :default option" do
    test "must not be given to leaf node" do
      assert_raise StatechartError, ~r/cannot assign a default to a leaf/, fn ->
        statechart_test_module do
          statechart do
            state :a, default: :b
            state :b
          end
        end
      end
    end

    test "raises if target is not a descendent" do
      assert_raise StatechartError, ~r/must be a descendent/, fn ->
        statechart_test_module do
          statechart do
            state :a, default: :b do
              state :c
            end

            state :b
          end
        end
      end
    end
  end

  describe "Statechart.state/X options list" do
    test "is optional" do
      statechart_test_module mod do
        statechart default: :child_state do
          state :parent_state do
            state :child_state
          end
        end
      end

      assert [:parent_state, :child_state] == mod.new |> Statechart.states()
    end

    test "is arg2 for arity-2" do
      statechart_test_module mod do
        statechart default: :alpaca do
          state :alpaca, entry: &List.wrap/1
        end
      end

      mod.new |> assert_context([])
    end

    test "is arg2 for arity-3" do
      statechart_test_module mod do
        statechart default: :beetle do
          state :alpaca, entry: &List.wrap/1 do
            state :beetle
          end
        end
      end

      mod.new |> assert_context([])
    end

    test "will throw if passed invalid key" do
      assert_raise ArgumentError, ~r/Allowed opts for state are/, fn ->
        statechart_test_module do
          statechart default: :battlestar do
            state :alpaca, invalid_key: :blarg
          end
        end
      end
    end
  end

  test "Statechart.state/X correctly nests states" do
    statechart_test_module mod do
      statechart default: :d do
        state :a do
          state :b, event: :GOTO_D >>> :d do
            state :c do
              state :d
            end
          end
        end
      end
    end

    schema = mod.__schema__()
    tree = Schema.tree(schema)
    {^mod, 5} = d_node_local_id = tree |> Tree.fetch_node!(name: :d) |> Node.local_id()
    {:ok, d_path} = Tree.fetch_ancestors_and_self(tree, local_id: d_node_local_id)
    assert length(d_path) == 5
    d_path_as_atoms = Enum.map(d_path, &Node.name/1)
    assert d_path_as_atoms == [mod | ~w/a b c d/a]
  end

  test "Statechart.state/X :exit/entry option" do
    statechart_test_module mod do
      statechart default: :a,
                 entry: fn -> IO.puts("put s") end,
                 event: :GOTO_B >>> :b do
        state :a, exit: fn -> IO.puts("put a") end
        state :b, entry: fn -> IO.puts("put b") end
      end
    end

    captured_io = ExUnit.CaptureIO.capture_io(fn -> mod.new() |> Statechart.trigger(:GOTO_B) end)

    assert captured_io =~ "put s"
    assert captured_io =~ "put a"
    assert captured_io =~ "put b"
  end

  # LATER test various ways of declaring action functions
  describe "Statechart.state/2 :subchart option" do
    subchart_new module: Subchart, default: :on do
      state :on
      state :off
    end

    test "inserts a subchart" do
      statechart_test_module mod do
        statechart default: :flarb do
          state :flarb
          # LATER change this to a state/2 :subchart option
          subchart :flazzl, Subchart
        end
      end

      schema = mod.__schema__()
      assert length(Schema.tree(schema) |> Tree.nodes()) == 6

      assert {^mod, 3} =
               schema |> Schema.tree() |> Tree.fetch_node!(name: :flazzl) |> Node.local_id()
    end

    test "throws if value is anything other than a module defining a Statechart" do
      assert_raise StatechartError, ~r/does not define a Statechart/, fn ->
        statechart_test_module do
          statechart do
            subchart :flazzl, "hi"
          end
        end
      end
    end
  end
end
