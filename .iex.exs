defmodule B do
  defmacro inject_blarg(type, val) do
    IO.inspect(type, label: :inject_blarg)

    quote do
      @spec gimme :: unquote(Macro.escape(type))
      def gimme, do: unquote(val)
    end
  end

  defmacro maybe_inject_blarg(opts \\ [])

  defmacro maybe_inject_blarg(context: {type, val}) do
    IO.inspect(type, label: :maybe_inject_blarg)

    quote do
      @type cherry :: unquote(type)
      @spec banana :: cherry()
      def banana, do: unquote(val)
    end
  end

  defmacro maybe_inject_blarg([]) do
    IO.inspect(quote(do: integer), label: :maybe_inject_blarg_default)
    nil
  end

  # defmacro inject_master(type, val) do
  #   quote do
  #     @spec gimme :: unquote(Macro.escape(type))
  #     def gimme, do: unquote(val)
  #   end
  # end

  def say_hi, do: IO.puts("hi")
end

defmodule M do
  require B
  B.inject_blarg(integer(), 42)
  B.maybe_inject_blarg(context: {integer, 42})
  B.maybe_inject_blarg()
end
