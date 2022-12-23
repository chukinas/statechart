defmodule Statechart.Build.MacroOpts do
  # LATER this doesn't need to be keyword list. I only ever implement the moduledoc key anyway
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Options operations for statechart/2 and state/3.
    """

  @doc """
  The keys allowed in the options for each macro.

  The order drives their display order in the docs
  """
  def __validation_keys__ do
    %{
      statechart: ~w/event default module entry context/a,
      subchart: ~w/default module entry exit/a,
      state: ~w/event default entry exit subchart/a
    }
  end

  def __doc_keys__ do
    %{
      event:
        "define transitions between states triggered by events (see [Events](#module-events))",
      subchart:
        "a {module, atom/keyword list} that defines a subchart (see [Subcharts](#module-subcharts))",
      # externals:
      #   "list of atoms that represent states that wire this subchart up to states in a parent statechart (see [Subcharts](#modules-subcharts))",
      default:
        "name of a child node to auto-transition to when this node is targeted. Required for any non-leaf node. (see [Defaults](#module-defaults))",
      entry:
        "an `t:action/0` to be executed when this node is entered (see [Actions](#module-actions))",
      exit:
        "an `t:action/0` to be executed when this node is exited (see [Actions](#module-actions))",
      context:
        "expects a tuple whose second element is `t:context/0` and the first is its type (see [Actions](#module-actions))",
      module:
        "nests the chart in a submodule of the given name (see [Submodules](#module-submodules))"
    }
  end

  @type macro :: :statechart | :state | :subchart

  @spec validate_keys(keyword, macro) :: :ok
  def validate_keys(opts, macro) do
    keys = opts |> Keyword.keys()
    valid_keys = __validation_keys__()[macro]

    if Enum.any?(keys, &(&1 not in valid_keys)) do
      raise(
        ArgumentError,
        "Allowed opts for #{macro} are #{inspect(valid_keys)}, got: #{inspect(keys)}"
      )
    end

    :ok
  end

  def escaped_actions(opts) do
    opts |> Keyword.take([:entry, :exit]) |> Macro.escape()
  end

  def events(opts) do
    Enum.flat_map(opts, fn
      {:event, event} -> [event]
      _ -> []
    end)
  end

  def docs(macro) do
    header = "## Options"

    bullet_points =
      for key <- __validation_keys__()[macro] do
        key_description = __doc_keys__()[key]
        "- `#{inspect(key)}` #{key_description}"
      end

    [header | bullet_points]
    |> Enum.intersperse("\n")
  end
end
