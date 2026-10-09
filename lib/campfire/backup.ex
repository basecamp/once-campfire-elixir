defmodule Campfire.Backup do
  @moduledoc "ONCE snapshot hook using a consistent SQLite backup while WAL writes continue."
  alias Campfire.SQLite

  def create do
    source = System.get_env("DATABASE_PATH", "/rails/storage/db/production.sqlite3")

    folder =
      System.get_env("BACKUP_PATH", Path.join(Path.dirname(Path.dirname(source)), "backups"))

    File.mkdir_p!(folder)
    destination = Path.join(folder, Path.basename(source))
    temporary = destination <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))
    {:ok, db} = SQLite.open(source, busy_timeout: 5000)

    try do
      {:ok, []} = SQLite.query(db, "VACUUM INTO ?", [temporary])
      :ok = File.rename(temporary, destination)
    after
      SQLite.close(db)
      File.rm(temporary)
    end
  end
end
