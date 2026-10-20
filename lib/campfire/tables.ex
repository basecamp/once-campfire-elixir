defmodule Campfire.Tables do
  @moduledoc """
  Owns the ETS tables that other processes read and write.

  A table is destroyed with the process that created it. Both memos used to create their table
  lazily from whichever request process arrived first — a Bandit connection process, which closes
  when the client disconnects. Requests then raced between a table that had just disappeared and
  the next one being created, and `:ets.insert/2` raised `ArgumentError` (a bad table identifier)
  which surfaced as a 500. Creating them here, under the supervisor, keeps the table identifier
  valid for the lifetime of the application.
  """
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_opts) do
    :ets.new(Campfire.Memo.table(), [
      :public,
      :named_table,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    Campfire.FragmentCache.setup()

    :ets.new(Campfire.SessionStore.table(), [
      :public,
      :named_table,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
