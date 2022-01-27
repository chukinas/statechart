defmodule Statechart.Build.MacroStatechart do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `Statechart.statechart` macro.
    """

  alias __MODULE__
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroState
  alias Statechart.Schema
  alias Statechart.Schema.Tree

  @spec build_ast(any, keyword) :: Macro.t()
  def build_ast(block, opts) do
    quote do
      if Module.has_attribute?(__MODULE__, :__sc_statechart__) do
        raise StatechartError, "Only one statechart call may be made per module"
      else
        Module.put_attribute(__MODULE__, :__sc_statechart__, nil)
      end

      Module.put_attribute(__MODULE__, :__statechart_inside_block__, nil)

      require MacroStatechart
      require Statechart.Build.AccStep, as: Step
      import Statechart

      Step.foreach do
        AccNodeStack.init(__ENV__)
        MacroStatechart.__do__(__ENV__, unquote(opts))
        unquote(block)
      end

      AccNodeStack.clean_up(__ENV__)

      @before_compile {MacroStatechart, :internal_api}
      if unquote(opts)[:include_public_api] do
        Module.put_attribute(__MODULE__, :before_compile, {MacroStatechart, :public_api})
      end

      Module.delete_attribute(__MODULE__, :__statechart_inside_block__)
    end
  end

  @spec __do__(Macro.Env.t(), keyword) :: :ok
  def __do__(env, opts) do
    # LATER test for bad default input in statechart
    case AccStep.get(env) do
      :insert_root_node -> init_schema(env)
      :insert_transitions_and_defaults -> MacroState.insert_default(env, opts)
      :validate -> validate_starting_node(env)
      _ -> :ok
    end

    :ok
  end

  defp init_schema(env) do
    schema = env |> AccNodeStack.location() |> Tree.new() |> Schema.from_tree()
    AccSchema.init(env, schema)

    :ok
  end

  defp validate_starting_node(env) do
    case env
         |> AccSchema.get()
         |> Schema.fetch_start_node() do
      {:ok, _start_node} -> :ok
      :error -> raise(StatechartError, "whoopsie, you need to set a default state")
    end
  end

  defmacro internal_api(env) do
    schema = AccSchema.get(env)
    AccNodeStack.clean_up(env)

    quote do
      alias Statechart.Machine

      @spec __schema__ :: Schema.t()
      def __schema__, do: unquote(Macro.escape(schema))

      @spec __tree__ :: Tree.t()
      def __tree__ do
        __schema__() |> Schema.tree()
      end

      @spec __nodes__ :: [Statechart.Schema.Node.t(), ...]
      def __nodes__ do
        __tree__() |> Tree.nodes()
      end
    end
  end

  defmacro public_api(_env) do
    quote do
      alias Statechart.Machine
      @spec new :: Machine.t()
      def new, do: Machine.__new__(__MODULE__)
    end
  end

  # LATER: can this be a function?
  defmacro throw_if_not_in_statechart_block(error_msg) do
    quote do
      unless Module.has_attribute?(__MODULE__, :__statechart_inside_block__) do
        raise StatechartError, unquote(error_msg)
      end
    end
  end
end
