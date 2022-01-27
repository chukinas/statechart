defmodule StatechartError do
  @moduledoc """
  Raised at compile time when anything inside `Statechart.statechart/2` fails validation.

  See `Statechart` macros for details.
  """
  defexception [:message]
end
