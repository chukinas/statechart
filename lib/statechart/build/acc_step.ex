defmodule Statechart.Build.AccStep do
  use Statechart.Util.DevOnlyDocs,
    moduledoc: """
    A Statechart is built up over several steps
    """

  #####################################
  # API

  @type t ::
          :insert_root_node
          | :insert_nodes
          | :insert_transitions_and_defaults
          | :insert_subcharts
          | :insert_actions
          | :validate

  @spec get(Macro.Env.t()) :: t()
  def get(env) do
    Module.get_attribute(env.module, :__statechart_build_step__)
  end

  defmacro foreach(do: do_block) do
    quote do
      for build_step <- unquote(__MODULE__).__list__() do
        unquote(__MODULE__).__set__(__ENV__, build_step)
        unquote(do_block)
        unquote(__MODULE__).__clean_up__(__ENV__)
      end
    end
  end

  #####################################
  # "PRIVATE" HELPERS

  @spec __list__ :: [t]
  def __list__ do
    # CONSIDER do transitions, default, and subcharts.. can they all go at the same time?
    ~w/
    insert_root_node
    insert_nodes
    insert_subcharts
    insert_actions
    insert_transitions_and_defaults
    validate
    /a
  end

  @spec __set__(Macro.Env.t(), t) :: Macro.Env.t()
  def __set__(env, step) do
    Module.put_attribute(env.module, :__statechart_build_step__, step)
    env
  end

  @spec __clean_up__(Macro.Env.t()) :: t()
  def __clean_up__(env) do
    Module.delete_attribute(env.module, :__statechart_build_step__)
    env
  end
end
