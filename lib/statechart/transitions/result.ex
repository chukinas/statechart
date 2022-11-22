defmodule Statechart.Transitions.Result do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Result
    """

  use TypedStruct
  alias Statechart.Schema.Location
  alias Statechart.Schema.Node

  typedstruct do
    field :local_id, Location.local_id()
    field :state_name, Statechart.state()
    field :context, term()
  end

  @spec new(Node.t(), context :: term) :: t
  def new(destination_node, context \\ nil),
    do: %__MODULE__{
      local_id: Node.local_id(destination_node),
      state_name: Node.name(destination_node),
      context: context
    }
end
