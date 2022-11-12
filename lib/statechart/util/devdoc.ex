defmodule Statechart.Util.DevOnlyDocs do
  @moduledoc false
  @render? System.get_env("RENDERDEVDOCS") == "true"

  defmacro __using__([{:moduledoc, moduledoc}]) do
    quote do
      @moduledoc unquote(@render?) && unquote(moduledoc)
    end
  end
end
