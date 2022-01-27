defmodule Statechart.Schema.Transition do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """

    """

  use TypedStruct
  alias Statechart.Schema.Event
  alias Statechart.Schema.Location

  typedstruct enforce: true do
    field :event, Event.t()
    field :target_local_id, Location.local_id()
    field :location, Location.t()
  end

  #####################################
  # CONSTRUCTORS

  @spec new(Event.t(), Location.local_id(), module, pos_integer, Location.node_index()) :: t()
  def new(event, target_local_id, module, line, parent_node_index) do
    location = Location.new(module, line, parent_node_index)
    %__MODULE__{event: event, target_local_id: target_local_id, location: location}
  end

  #####################################
  # CONSTRUCTORS

  def target_local_id(%__MODULE__{target_local_id: val}), do: val
  def event(%__MODULE__{event: val}), do: val

  #####################################
  # CONVERTERS

  def line_number(%__MODULE__{location: location}) do
    Location.line(location)
  end

  #####################################
  # IMPLEMENTATIONS

  alias __MODULE__

  defimpl Inspect do
    def inspect(%Transition{event: event, target_local_id: target_local_id}, _opts) do
      "#Transition<#{Event.pretty(event)} >>> #{inspect(target_local_id)}>"
    end
  end
end
