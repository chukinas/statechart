defmodule Statechart.Util.DevOnlyDocs do
  @moduledoc false
  @render? System.get_env("RENDERDEVDOCS") == "true"
  # @render? true

  defmacro __using__([{:moduledoc, moduledoc}]) do
    if @render? do
      quote do
        @moduledoc unquote(moduledoc)
      end
    else
      quote do
        @moduledoc false
      end
    end
  end
end
