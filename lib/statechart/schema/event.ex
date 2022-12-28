defmodule Statechart.Schema.Event do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Functions for working with Events.
    """

  @typedoc """
  Valid value for registering transitions via `Statechart.statechart/2` and `Statechart.state/3` :event option

  We recommend following a statechart convention and using uppercase for simple
  atom events, example: `:MY_EVENT`.

  Alternatively, you can use a module name.
  This module must define a struct that implements the `Statechart.Schema.Event` protocol.
  Normally, this is done via `use Statechart.Schema.Event`.
  """
  @type t :: term

  #####################################
  # CONVERTERS

  @spec validate(t()) :: :ok | :error
  def validate(event) when is_atom(event), do: :ok
  def validate(_event), do: :error

  @spec match?(t, t) :: boolean
  def match?(event1, event2) do
    event1 == event2
  end

  @spec pretty(t) :: String.t()
  def pretty(event) do
    try do
      event
      |> Module.split()
      |> Enum.at(-1)
    rescue
      _ -> to_string(event)
    end
  end
end
