defmodule Campfire.FragmentCache do
  @moduledoc "Bounded application fragments shared by request and broadcast rendering."
  use Agent

  def start_link(_) do
    Agent.start_link(
      fn ->
        :ets.new(Campfire.DecodedFragments, [:named_table, :set, :public, read_concurrency: true])
        %{}
      end,
      name: __MODULE__
    )
  end

  @external_resource "vectors/fragment-digests.json"
  @digests Jason.decode!(File.read!(@external_resource))

  def record(kind, record, render) do
    {key, version} = identity(kind, record)

    if Process.whereis(Campfire.Redis) do
      case Redix.command(Campfire.Redis, ["GET", key]) do
        {:ok, data} ->
          case load(key, data, version) do
            {:ok, html} -> html <> "\n"
            :miss -> write(key, version, render)
          end

        _ ->
          render.()
      end
    else
      fetch({kind, record}, render)
    end
  end

  def records(_kind, [], _render), do: []

  def records(kind, records, render) do
    if Process.whereis(Campfire.Redis) do
      identities = Enum.map(records, &identity(kind, &1))

      case Redix.command(Campfire.Redis, ["MGET" | Enum.map(identities, &elem(&1, 0))]) do
        {:ok, values} ->
          Enum.zip([records, identities, values])
          |> Enum.map(fn {record, {key, version}, data} ->
            case load(key, data, version) do
              {:ok, html} -> html <> "\n"
              :miss -> write(key, version, fn -> render.(record) end)
            end
          end)

        _ ->
          Enum.map(records, render)
      end
    else
      Enum.map(records, &record(kind, &1, fn -> render.(&1) end))
    end
  end

  # Redis remains authoritative: reuse only an identical nonexpiring entry.
  defp load(key, <<0, 17, _flag, expires::little-float-size(64), _::binary>> = data, version)
       when expires < 0 and byte_size(data) <= 262_144 do
    case :ets.lookup(Campfire.DecodedFragments, key) do
      [{^key, ^data, ^version, html}] ->
        {:ok, html}

      _ ->
        case Campfire.Rails.Cache.load(data, version) do
          {:ok, html} = result ->
            if :ets.info(Campfire.DecodedFragments, :size) >= 2048,
              do: :ets.delete_all_objects(Campfire.DecodedFragments)

            :ets.insert(Campfire.DecodedFragments, {key, data, version, html})
            result

          :miss ->
            :miss
        end
    end
  end

  defp load(_key, data, version), do: Campfire.Rails.Cache.load(data, version)

  defp identity(kind, record) do
    table = if kind == :message, do: "messages", else: "boosts"
    template = if kind == :message, do: "messages/_message", else: "messages/boosts/_boost"
    suffix = if kind == :message, do: "/presentation-v3", else: ""
    key = "views/#{template}:#{@digests[template]}/#{table}/#{record["id"]}#{suffix}"

    version =
      record["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.pad_trailing(20, "0")

    {key, version}
  end

  defp write(key, version, render) do
    html = render.()

    Redix.command(Campfire.Redis, [
      "SET",
      key,
      Campfire.Rails.Cache.dump(String.trim_trailing(html, "\n"), version)
    ])

    html
  end

  def fetch(key, render) do
    case Agent.get(__MODULE__, &Map.fetch(&1, key)) do
      {:ok, html} ->
        html

      :error ->
        html = render.()

        Agent.get_and_update(__MODULE__, fn cache ->
          case Map.fetch(cache, key) do
            {:ok, existing} ->
              {existing, cache}

            :error ->
              {html, Map.put(if(map_size(cache) >= 4096, do: %{}, else: cache), key, html)}
          end
        end)
    end
  end
end
