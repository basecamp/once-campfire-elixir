defmodule Campfire.CookieMemo do
  @moduledoc """
  Owns the table Campfire.Auth uses for cookie values.

  Bandit serves every request in a fresh process, so a process dictionary cannot carry a signed
  cookie from one request to the next. Keys include the second or the session, which bounds the
  table by the work actually in flight; entries older than the current second are swept.
  """
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_opts) do
    :ets.new(Campfire.Auth.cookie_memo(), [
      :public,
      :named_table,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
