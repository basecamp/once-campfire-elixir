defmodule Campfire.CacheEpoch do
  @moduledoc """
  Captures the response cache's database version once per request, before authentication runs.

  `Auth.session_lookup` memoises reads by that version and the cache plug admits and serves by it,
  so taking it here turns two serialised calls into the cache process into one.
  """
  def init(options), do: options

  def call(conn, options) do
    do_call(conn, options)
  end

  defp do_call(conn, _options) do
    _ = Campfire.ResponseCache.capture_version()
    conn
  end
end
