defmodule Statechart.SubchartTest do
  use Statechart.Case
  doctest Statechart

  test "Statechart.subchart/2 raises if passed an invalid option" do
    assert_raise ArgumentError, ~r/Allowed opts for subchart are/, fn ->
      statechart_test_module do
        subchart invalid_opt: :invalid_value
      end
    end
  end

  test "Statechart.subchart/2 has no required options" do
    statechart_test_module do
      subchart []
    end
  end

  describe "Statechart.subchart/2 :default option" do
    test "is required if any states are declared" do
      assert_raise StatechartError, ~r/need to set a default state/, fn ->
        statechart_test_module do
          subchart do
            state :foo
          end
        end
      end
    end

    test "is optional if no states are declared" do
      statechart_test_module do
        subchart do: nil
      end
    end
  end

  describe "Statechart.subchart/2 :module option" do
    test "wraps the chart in a child module" do
      module_name = module_name()
      assert {:module, ^module_name, _, nil} = subchart(module: module_name)
    end
  end

  describe "Statechart.subchart/2 :entry option" do
    test "defines an action that is executed when subchart is entered" do
      {:module, subchart_name, _, _} =
        defmodule unique_module_name() do
          # TODO change this back to subchart
          subchart entry: &(&1 + 1)
        end

      statechart_test_module mod do
        statechart context: {integer, 0}, default: :my_subchart do
          state :my_subchart, subchart: subchart_name
        end
      end

      mod.new |> assert_context(1)
    end
  end

  describe "Statechart.subchart/2 :exit and :entry options" do
    test "define actions that are executed when subchart is entered / exited" do
      statechart_test_module subchart_mod do
        subchart entry: &[:just_entered | &1], exit: &[:just_exited | &1]
      end

      statechart_test_module statechart_mod do
        statechart context: {[atom], []}, default: :alpaca do
          state :alpaca, subchart: subchart_mod, event: :DONUT >>> :beetle
          state :beetle
        end
      end

      machine = statechart_mod.new()
      assert [:alpaca] = Statechart.states(machine)
      assert [:just_entered] = Statechart.context(machine)

      machine = Statechart.trigger(machine, :DONUT)
      assert [:beetle] = Statechart.states(machine)
      assert :just_exited in Statechart.context(machine)
    end
  end

  # LATER implement externals
  # describe "Statechart.subchart/2 :externals option" do
  #   test "must take a non-empty list of atoms"
  #   test "makes available each atom as a target-state"
  # end

  describe "state names within the subchart" do
    test "must be unique" do
      # This doesn't raise...
      subchart module: unique_module_name(), default: :alpaca do
        state :alpaca
        state :beetle
      end

      # ...but this does
      assert_raise StatechartError, ~r/state with name :alpaca was already defined on line/, fn ->
        subchart module: unique_module_name(), default: :alpaca do
          state :alpaca
          state :alpaca
        end
      end
    end

    test "do not have to be unique in the chart that it's inserted into" do
      statechart_test_module subchart_mod do
        subchart default: :alpaca do
          state :alpaca
          state :beetle
        end
      end

      statechart module: unique_module_name(), default: :alpaca do
        state :alpaca
        state :beetle
        state :kraken, subchart: subchart_mod
      end
    end
  end

  test "a very simple subchart example" do
    defmodule MyBlargMaster do
      subchart entry: &(&1 + 1)
    end

    defmodule MyStyro do
      statechart default: :the_only_state, context: {integer, 0} do
        state :the_only_state, subchart: MyBlargMaster
      end
    end

    MyStyro.new() |> assert_context(1)
  end

  describe "blarg" do
    test "for a subchart root having actions declared at both the subchart and parent levels" do
      defmodule SubchartRootActionsBothLocalAndFromParent do
        use Statechart

        def action_entering_foo(_context), do: IO.puts("action declared by parent!")
        def action_entering_subchart(_context), do: IO.puts("action declared by subchart!")

        defmodule Subchart do
          subchart entry: &SubchartRootActionsBothLocalAndFromParent.action_entering_subchart/1
        end

        statechart default: :bar, event: :GOTO_FOO >>> :foo do
          state :foo, subchart: Subchart, entry: &__MODULE__.action_entering_foo/1
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
  end
end
