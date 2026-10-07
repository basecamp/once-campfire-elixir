defmodule Campfire.QR do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Pinned RQRCode mask scoring and SVG output over a native Elixir encoder."
  alias QQR.Encoder.{Data, Format, Mask, Matrix}
  import Plug.Conn

  def show(conn, id) do
    normalized = id |> String.replace("-", "+") |> String.replace("_", "/")
    normalized = normalized <> String.duplicate("=", rem(4 - rem(byte_size(normalized), 4), 4))

    with {:ok, text} <- Base.decode64(normalized),
         true <- Base.encode64(text) == normalized,
         {:ok, svg} <- svg(text) do
      conn
      |> put_resp_content_type("image/svg+xml")
      |> put_resp_header("cache-control", "max-age=31556952, public")
      |> send_resp(200, svg)
    else
      _ ->
        Campfire.HttpResponse.exception(conn, 500, Campfire.Assets.read("public/500.html"))
    end
  end

  def svg(text) do
    case matrix(text) do
      {:ok, %{size: size, modules: modules}} ->
        dimension = size * 11

        rects =
          for row <- 0..(size - 1),
              col <- 0..(size - 1),
              Map.get(modules, {row, col}, false),
              do: ~s(<rect width="11" height="11" x="#{col * 11}" y="#{row * 11}" fill="black"/>)

        {:ok,
         IO.iodata_to_binary([
           ~s(<?xml version="1.0" standalone="yes"?><svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:ev="http://www.w3.org/2001/xml-events" viewBox="0 0 #{dimension} #{dimension}" shape-rendering="crispEdges"><rect width="#{dimension}" height="#{dimension}" x="0" y="0" fill="white"/>),
           rects,
           "</svg>"
         ])}

      error ->
        error
    end
  end

  def matrix(text) do
    mode =
      cond do
        Regex.match?(~r/\A[0-9]*\z/, text) -> :numeric
        Regex.match?(~r/\A[0-9A-Z $%*+\-.\/:]+\z/, text) -> :alphanumeric
        true -> :byte
      end

    with {:ok, %{version: version, bits: bits}} <-
           Data.encode_data(text, ec_level: :high, mode: mode) do
      size = QQR.Version.dimension(version)
      base = Matrix.build(version, bits) |> Map.put({size - 8, 8}, false)

      {mask, masked, _} =
        0..7
        |> Enum.map(fn mask ->
          masked = Mask.apply_mask(base, mask, size, version)
          {mask, masked, penalty(masked, size)}
        end)
        |> Enum.min_by(&elem(&1, 2))

      final =
        masked
        |> Map.put({size - 8, 8}, true)
        |> Format.write_format_info(:high, mask, size)
        |> Format.write_version_info(version, size)

      {:ok, %{version: version, size: size, mask: mask, modules: final}}
    end
  end

  defp penalty(matrix, size) do
    flat = for row <- 0..(size - 1), col <- 0..(size - 1), do: Map.get(matrix, {row, col}, false)
    grid = List.to_tuple(flat)
    neighbors = for dr <- -1..1, dc <- -1..1, dr != 0 || dc != 0, do: {dr, dc}

    level1 =
      for row <- 0..(size - 1), col <- 0..(size - 1), reduce: 0 do
        sum ->
          value = elem(grid, row * size + col)

          same =
            Enum.count(neighbors, fn {dr, dc} ->
              r = row + dr
              c = col + dc
              r >= 0 && r < size && c >= 0 && c < size && elem(grid, r * size + c) == value
            end)

          sum + if(same > 5, do: 3 + same - 5, else: 0)
      end

    level2 =
      for row <- 0..(size - 2), col <- 0..(size - 2), reduce: 0 do
        sum ->
          value = elem(grid, row * size + col)

          sum +
            if(
              value == elem(grid, row * size + col + 1) &&
                value == elem(grid, (row + 1) * size + col) &&
                value == elem(grid, (row + 1) * size + col + 1),
              do: 3,
              else: 0
            )
      end

    pattern = [true, false, true, true, true, false, true]

    level3 =
      for axis <- [:row, :col], outer <- 0..(size - 1), start <- 0..(size - 7), reduce: 0 do
        sum ->
          sequence =
            for i <- 0..6,
                do:
                  elem(
                    grid,
                    if(axis == :row,
                      do: outer * size + start + i,
                      else: (start + i) * size + outer
                    )
                  )

          sum + if(sequence == pattern, do: 40, else: 0)
      end

    ratio = Enum.count(flat, & &1) / (size * size)
    level1 + level2 + level3 + abs(100 * ratio - 50) / 5 * 10
  end
end
