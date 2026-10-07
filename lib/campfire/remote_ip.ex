defmodule Campfire.RemoteIP do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "ActionDispatch remote address selection and default trusted proxies."
  import Plug.Conn

  def address(conn) do
    remote = conn.remote_ip |> :inet.ntoa() |> to_string()
    forwarded = addresses(get_req_header(conn, "x-forwarded-for")) |> Enum.reverse()
    client = addresses(get_req_header(conn, "client-ip")) |> Enum.reverse()

    if client != [] && forwarded != [] && List.last(client) not in forwarded,
      do: raise(ArgumentError, "IP spoofing attack")

    ips = forwarded ++ client
    Enum.find(ips ++ [remote], &(!trusted?(&1))) || List.last(ips) || remote
  end

  defp addresses(headers) do
    headers
    |> Enum.flat_map(&String.split(&1, ~r/[ ,]+/, trim: true))
    |> Enum.filter(fn value ->
      match?({:ok, _}, :inet.parse_strict_address(String.to_charlist(value)))
    end)
  end

  defp trusted?(value) do
    case :inet.parse_strict_address(String.to_charlist(value)) do
      {:ok, {a, _, _, _}} when a in [10, 127] -> true
      {:ok, {172, b, _, _}} when b in 16..31 -> true
      {:ok, {192, 168, _, _}} -> true
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} -> true
      {:ok, {a, _, _, _, _, _, _, _}} when a in 0xFC00..0xFDFF or a in 0xFE80..0xFEBF -> true
      _ -> false
    end
  end
end
