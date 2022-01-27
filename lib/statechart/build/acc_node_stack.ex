defmodule Statechart.Build.AccNodeStack do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    Keeps track of the node we're currently in.
    For each `state` call, that node's local ID is pushed onto the stack.
    When that state's do-block is finally closed, the local id is popped off the stack.
    """

  alias Statechart.Schema.Location

  #####################################
  # REDUCERS

  def init(env) do
    root_index = 1
    Module.put_attribute(env.module, :__statechart_node_stack__, [root_index])
    Module.put_attribute(env.module, :__statechart_node_index__, root_index)
    env
  end

  @spec clean_up(Macro.Env.t()) :: Macro.Env.t()
  def clean_up(env) do
    Module.delete_attribute(env.module, :__statechart_node_stack__)
    Module.delete_attribute(env.module, :__statechart_node_index__)
    env
  end

  def __on_enter__(env) do
    module = env.module
    node_index_stack = Module.get_attribute(module, :__statechart_node_stack__)
    current_node_index = Module.get_attribute(module, :__statechart_node_index__)
    next_node_index = 1 + current_node_index
    Module.put_attribute(module, :__statechart_node_stack__, [next_node_index | node_index_stack])
    Module.put_attribute(module, :__statechart_node_index__, next_node_index)
    env
  end

  def __on_exit__(env) do
    module = env.module
    [_current_node_id | node_id_stack] = Module.get_attribute(module, :__statechart_node_stack__)
    Module.put_attribute(module, :__statechart_node_stack__, node_id_stack)
    env
  end

  defmacro node_stack(do: do_block) do
    quote do
      unquote(__MODULE__).__on_enter__(__ENV__)
      unquote(do_block)
      unquote(__MODULE__).__on_exit__(__ENV__)
    end
  end

  #####################################
  # CONVERTERS

  @spec parent_local_id(Macro.Env.t()) :: Location.local_id()
  def parent_local_id(env) do
    module = env.module

    [_current_local_id, parent_local_id | _] =
      Module.get_attribute(module, :__statechart_node_stack__)

    {module, parent_local_id}
  end

  @spec location(Macro.Env.t()) :: Location.t()
  def location(env) do
    module = env.module
    [current_node_index | _] = Module.get_attribute(module, :__statechart_node_stack__)
    Location.new(module, env.line, current_node_index)
  end

  @spec local_id(Macro.Env.t()) :: Location.local_id()
  def local_id(env) do
    [current_node_index | _] = Module.get_attribute(env.module, :__statechart_node_stack__)
    {env.module, current_node_index}
  end
end
