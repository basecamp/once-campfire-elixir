defmodule Campfire.HtmlParser do
  @moduledoc """
  Gumbo HTML parsing pinned to the Rails reference's Nokogiri version, as a
  NIF. Elements are `{name, [{attribute, value}], children}`, comments
  `{:comment, text}` and text nodes binaries.

  Each parse may allocate at most 256 MiB. Exceeding it raises
  `ArgumentError`: the vendored Gumbo is built so that allocation failures
  return to the NIF, which frees the partial parse, instead of aborting.
  """
  @on_load :load
  # Crafted markup can expand far beyond its size, so all but small fragments
  # parse on a dirty scheduler and never hold a normal one.
  @dirty_bytes 1_024

  @doc false
  def load do
    :campfire
    |> :code.priv_dir()
    |> Path.join("native/campfire_html")
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  def parse(html) do
    nodes = if byte_size(html) > @dirty_bytes, do: parse_dirty(html), else: parse_nif(html)

    case nodes do
      {:error, message} -> raise ArgumentError, to_string(message)
      nodes -> nodes
    end
  end

  @doc false
  def parse_nif(_html), do: :erlang.nif_error(:not_loaded)

  @doc false
  def parse_dirty(_html), do: :erlang.nif_error(:not_loaded)

  # A parse with a lower allocation limit in bytes, for tests.
  @doc false
  def parse_limited(_html, _limit), do: :erlang.nif_error(:not_loaded)
end
