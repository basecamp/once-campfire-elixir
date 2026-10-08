defmodule Campfire.ModelCache do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Active Record cache keys and controller model validators."
  import Plug.Conn
  @external_resource "vectors/image-etags.json"
  @avatar_digest Jason.decode!(File.read!(@external_resource))["Users::AvatarsController"][
                   "digest"
                 ]

  defp cache_key(table, record) do
    version = record["updated_at"] || record["created_at"]

    if version do
      stamp = version |> String.replace(~r/[^0-9]/, "") |> String.pad_trailing(20, "0")
      "#{table}/#{record["id"]}-#{stamp}"
    else
      "#{table}/#{record["id"]}"
    end
  end

  def stale(conn, table, record)
  def stale(conn, _, nil), do: {:stale, conn}

  def stale(conn, table, record) do
    {_, data} = Campfire.Auth.browser_session(conn)
    flash = get_in(data, ["flash", "flashes"]) || %{}
    svg? = Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "image/svg+xml"))
    etag = etag(table, record, svg?, flash)

    conn =
      conn
      |> put_resp_header("etag", etag)
      |> put_resp_header("cache-control", "max-age=0, private, must-revalidate")

    matches =
      get_req_header(conn, "if-none-match")
      |> Enum.join(",")
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    fresh = etag in matches || "*" in matches

    if fresh,
      do: {:fresh, conn |> put_resp_header("cache-control", "no-cache") |> send_resp(304, "")},
      else: {:stale, conn}
  end

  def etag(table, record, svg? \\ false, flash \\ %{}) do
    key = cache_key(table, record)
    key = if table == "users" && svg?, do: key <> "/" <> @avatar_digest, else: key

    key =
      Enum.reduce(flash, key, fn {name, value}, acc ->
        acc <> "/" <> name <> "/" <> to_string(value)
      end)

    digest = :crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 32)
    ~s(W/"#{digest}")
  end
end
