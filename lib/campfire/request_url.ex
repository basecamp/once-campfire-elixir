defmodule Campfire.RequestURL do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Rails URL context from the local Thruster upstream connection only."
  import Plug.Conn
  def init(opts), do: opts
  # Production binds the upstream to loopback. Other peers cannot supply proxy context.
  def call(%{remote_ip: peer} = conn, _) when peer in [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}],
    do: local_proxy(conn)

  def call(conn, _), do: conn

  defp local_proxy(conn) do
    proto = forwarded(header(conn, "forwarded") || "") |> Map.get("proto", []) |> List.last()
    proto = if proto in ~w(http https ws wss), do: proto, else: nil
    proto = proto || scheme(conn, "x-forwarded-proto") || scheme(conn, "x-forwarded-scheme")
    ssl = header(conn, "x-forwarded-ssl") == "on" || proto in ["https", "wss"]
    scheme = if ssl, do: :https, else: conn.scheme
    authority = header(conn, "x-forwarded-host")

    authority =
      if authority in [nil, ""],
        do: header(conn, "host"),
        else: authority |> String.split(~r/,\s?/) |> List.last()

    if authority do
      case Regex.run(~r/^(.*):(\d+)$/, authority) do
        [_, host, port] ->
          %{conn | scheme: scheme, host: host, port: String.to_integer(port)}

        _ ->
          %{conn | scheme: scheme, host: authority, port: if(scheme == :https, do: 443, else: 80)}
      end
    else
      %{conn | scheme: scheme}
    end
  end

  defp header(conn, name), do: List.first(get_req_header(conn, name))

  defp scheme(conn, name),
    do:
      (header(conn, name) || "")
      |> String.split(~r/\s*,\s*/)
      |> Enum.reverse()
      |> Enum.find(&(&1 in ~w(http https ws wss)))

  defp forwarded(raw), do: parse(String.replace(raw, "\n", ";"), %{}, 0, 0)
  defp parse(_, _, count, _) when count >= 1024, do: %{}
  defp parse(_, _, _, escapes) when escapes > 1024, do: %{}

  defp parse(raw, params, count, escapes) do
    raw = String.replace(raw, ~r/^[\s;,]+/, "")

    case :binary.split(raw, "=") do
      [name, rest] ->
        name = name |> String.trim() |> String.downcase()

        if name in ~w(by for host proto) do
          {value, rest, escapes} = value(rest, escapes)
          parse(rest, Map.update(params, name, [value], &(&1 ++ [value])), count + 1, escapes)
        else
          %{}
        end

      _ ->
        params
    end
  end

  defp value(<<34, rest::binary>>, escapes), do: quoted(rest, "", escapes)

  defp value(rest, escapes) do
    case Regex.split(~r/[;,]/, rest, parts: 2) do
      [value, tail] -> {String.trim(value), tail, escapes}
      [value] -> {String.trim(value), "", escapes}
    end
  end

  defp quoted(<<34, rest::binary>>, value, escapes), do: {value, rest, escapes}

  defp quoted(<<92, byte, rest::binary>>, value, escapes),
    do: quoted(rest, value <> <<byte>>, escapes + 1)

  defp quoted(<<byte, rest::binary>>, value, escapes),
    do: quoted(rest, value <> <<byte>>, escapes)

  defp quoted("", value, escapes), do: {value, "", escapes}
end
