defmodule Campfire.Backup do
  @moduledoc "ONCE snapshot hook using a consistent SQLite backup while WAL writes continue."
  alias Exqlite.Sqlite3, as: SQL

  def create do
    source = System.get_env("DATABASE_PATH", "/rails/storage/db/production.sqlite3")

    folder =
      System.get_env("BACKUP_PATH", Path.join(Path.dirname(Path.dirname(source)), "backups"))

    File.mkdir_p!(folder)
    destination = Path.join(folder, Path.basename(source))
    temporary = destination <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))
    {:ok, db} = SQL.open(source)

    try do
      :ok = SQL.set_busy_timeout(db, 5000)
      {:ok, statement} = SQL.prepare(db, "VACUUM INTO ?")

      try do
        :ok = SQL.bind(statement, [temporary])
        {:ok, []} = SQL.fetch_all(db, statement)
        :ok = File.rename(temporary, destination)
      after
        SQL.release(db, statement)
      end
    after
      SQL.close(db)
      File.rm(temporary)
    end
  end
end
