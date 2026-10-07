defmodule Campfire.Sigils do
  @moduledoc """
  A drop-in `~r` that compiles each literal regex once per node.

  Under OTP 28, Elixir's `~r` re-imports the compiled pattern every time the
  expression is evaluated. This sigil validates the regex at compile time with
  `Kernel.sigil_r/2`, then compiles its source and options once at runtime and
  keeps the result in `:persistent_term`. Interpolated regexes fall back to
  `Kernel.sigil_r/2`.

      import Kernel, except: [sigil_r: 2]
      import Campfire.Sigils
  """

  defmacro sigil_r({:<<>>, _, [binary]} = term, modifiers) when is_binary(binary) do
    {%Regex{source: source, opts: opts}, _} =
      Code.eval_quoted(quote(do: Kernel.sigil_r(unquote(term), unquote(modifiers))))

    quote do: Campfire.Sigils.regex(unquote(Macro.escape({source, opts})))
  end

  defmacro sigil_r(term, modifiers) do
    quote do: Kernel.sigil_r(unquote(term), unquote(modifiers))
  end

  @doc false
  def regex({source, opts} = key) do
    key = {__MODULE__, key}

    case :persistent_term.get(key, nil) do
      nil ->
        regex = Regex.compile!(source, opts)
        :persistent_term.put(key, regex)
        regex

      regex ->
        regex
    end
  end
end
