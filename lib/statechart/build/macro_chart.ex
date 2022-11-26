defmodule Statechart.Build.MacroChart do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    This module does the heavy lifting for the `statechart` and `subchart` macros.
    """

  alias Statechart.Build.AccFunctions
  alias Statechart.Build.AccNodeStack
  alias Statechart.Build.AccSchema
  alias Statechart.Build.AccStep
  alias Statechart.Build.MacroState
  alias Statechart.Build.MacroChart
  alias Statechart.Build.MacroOpts
  alias Statechart.Schema
  alias Statechart.Schema.Node
  alias Statechart.Schema.Tree

  @spec build_ast(Schema.schema_type(), Keyword.t(), term) :: Macro.t()
  def build_ast(schema_type, opts, block) do
    :ok = MacroOpts.validate_keys(opts, schema_type)

    quote do
      MacroChart.__maybe_wrap_in_module__ unquote(opts[:module]) do
        @before_compile MacroChart
        MacroChart.__ensure_only_one_statechart_per_module__()
        MacroChart.__inject_context__(unquote(opts[:context]))

        MacroChart.__ensure_dsl_macros_can_only_be_called_within_statechart_ do
          AccStep.foreach do
            AccNodeStack.init(__ENV__)
            AccFunctions.init(__ENV__)

            MacroChart.__do__(
              __ENV__,
              unquote(schema_type),
              unquote(Keyword.take(opts, [:entry, :exit, :default]))
            )

            import Statechart
            unquote(block)
          end
        end
      end
    end
  end

  defmacro __maybe_wrap_in_module__(module, do: block) do
    if module do
      quote do
        defmodule unquote(module) do
          unquote(block)
        end
      end
    else
      quote do: (fn -> unquote(block) end).()
    end
  end

  defmacro __ensure_only_one_statechart_per_module__ do
    quote do
      if Module.has_attribute?(__MODULE__, :__statechart__) do
        raise StatechartError, "Only one statechart call may be made per module"
      else
        Module.put_attribute(__MODULE__, :__statechart__, nil)
      end
    end
  end

  defmacro __inject_context__(context) do
    {context_type, context_value} = if context, do: context, else: quote(do: {term, nil})

    quote do
      @type context :: unquote(context_type)
      @spec __context__() :: context()
      def __context__, do: unquote(context_value)
    end
  end

  # For ensuring certain macros can only be called within a statechart block
  defmacro __ensure_dsl_macros_can_only_be_called_within_statechart_(do: block) do
    quote do
      Module.put_attribute(__MODULE__, :__statechart_inside_block__, nil)
      unquote(block)
      Module.delete_attribute(__MODULE__, :__statechart_inside_block__)
    end
  end

  def __do__(env, chart_type, opts) do
    # LATER test for bad default input in statechart
    case AccStep.get(env) do
      :init ->
        init_schema(env, chart_type, Keyword.take(opts, ~w/entry exit/a))

      :insert_transitions_and_defaults ->
        case Keyword.fetch(opts, :default) do
          # LATER should insert_default take not an opts list?
          {:ok, default} -> MacroState.insert_default(env, default: default)
          :error -> :ok
        end

      :validate ->
        validate_starting_node(env)

      _ ->
        :ok
    end

    :ok
  end

  defp init_schema(env, chart_type, actions) do
    add_actions_fn =
      &Enum.reduce(actions, &1, fn {action_type, action}, root ->
        _placeholder = AccFunctions.put_and_get_placeholder(env, action)
        Node.add_action(root, action_type, action)
      end)

    schema =
      env
      |> AccNodeStack.location()
      |> Tree.new()
      |> Tree.update_root(add_actions_fn)
      |> Schema.new(type: chart_type)

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

  defmacro __before_compile__(env) do
    quote do
      unquote(__MODULE__).internal_api(unquote(env))
      unquote(__MODULE__).public_api(unquote(env))
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
      @spec new :: Statechart.t(context())
      def new do
        Machine.__new__(__MODULE__, __context__())
      end
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
