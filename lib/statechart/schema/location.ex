defmodule Statechart.Schema.Location do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Module, line number, and node index for uniquely identifying nodes.

    Used for generating clear exception messages and namespacing nodes.
    For example, the user can refer to a node by its name, but we raise an exception
    if that name isn't found among nodes defined in the current module.
    """

  use TypedStruct

  #####################################
  # TYPES

  @type node_index :: non_neg_integer
  @type local_id :: {module(), node_index()}

  typedstruct enforce: true do
    field :module, module
    field :line, pos_integer
    # Each statechart node get a unique index
    field :node_index, node_index()
  end

  #####################################
  # CONSTRUCTORS

  @spec new(module, pos_integer, node_index()) :: t
  def new(module, line, node_index) do
    %__MODULE__{
      module: module,
      line: line,
      node_index: node_index
    }
  end

  #####################################
  # CONVERTERS

  for field <- ~w/module line node_index/a do
    def unquote(field)(%__MODULE__{unquote(field) => val}), do: val
  end

  @spec local_id(t) :: local_id()
  def local_id(%__MODULE__{module: module, node_index: node_index}), do: {module, node_index}

  #####################################
  # IMPLEMENTATIONS

  defimpl Inspect do
    alias Statechart.Schema.Location

    def inspect(%Location{} = location, _opts) do
      pretty_module =
        try do
          location.module |> Module.split() |> Enum.at(-1)
        rescue
          ArgumentError -> location.module
        end

      "#Location<#{pretty_module}:#{location.line},#{location.node_index}>"
    end
  end
end
