defmodule Statechart.Build.MacroOpts do
  # LATER this doesn't need to be keyword list. I only ever implement the moduledoc key anyway
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Options operations for statechart/2 and state/3.
    """

  def __validation_keys__,
    do: %{
      statechart: ~w/default module entry context/a,
      subchart: ~w/default module entry exit/a,
      state: ~w/default entry exit/a
    }

  def __doc_keys__,
    do: %{
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
