defmodule Campfire.UserAgent do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Native port of the pinned useragent 0.16.11 product parser."
  defp matcher, do: ~r/\A['"]*([^\/\s]+)\/?([^\s,]*)(\s\(([^\)]*)\)|,gzip\(gfe\))?/

  @windows %{
    "10.0" => "Windows 10",
    "6.3" => "Windows 8.1",
    "6.2" => "Windows 8",
    "6.1" => "Windows 7",
    "6.0" => "Windows Vista",
    "5.2" => "Windows XP x64 Edition",
    "5.1" => "Windows XP",
    "5.01" => "Windows 2000, Service Pack 1 (SP1)",
    "5.0" => "Windows 2000",
    "4.0" => "Windows NT 4.0"
  }
  @builds %{
    "85.7" => "1.0",
    "85.8.5" => "1.0.3",
    "85.8.2" => "1.0.3",
    "124" => "1.2",
    "125.2" => "1.2.2",
    "125.4" => "1.2.3",
    "125.5.5" => "1.2.4",
    "125.5.6" => "1.2.4",
    "125.5.7" => "1.2.4",
    "312.1.1" => "1.3",
    "312.1" => "1.3",
    "312.5" => "1.3.1",
    "312.5.1" => "1.3.1",
    "312.5.2" => "1.3.1",
    "312.8" => "1.3.2",
    "312.8.1" => "1.3.2",
    "412" => "2.0",
    "412.6" => "2.0",
    "412.6.2" => "2.0",
    "412.7" => "2.0.1",
    "416.11" => "2.0.2",
    "416.12" => "2.0.2",
    "417.9" => "2.0.3",
    "418" => "2.0.3",
    "418.8" => "2.0.4",
    "418.9" => "2.0.4",
    "418.9.1" => "2.0.4",
    "419" => "2.0.4",
    "425.13" => "2.2",
    "534.52.7" => "5.1.2"
  }

  def parse(raw) do
    raw = raw || ""
    products = products(if(strip(raw) == "", do: "Mozilla/4.0 (compatible)", else: raw), [])
    first = List.first(products) || %{}
    last = List.last(products) || %{}
    comments = first[:comment] || []
    joined = Enum.join(comments, "; ")
    names = Enum.map(products, & &1.name)

    kind =
      cond do
        last[:name] == "Edge" ->
          :edge

        first[:comment] &&
            (contains(Enum.at(comments, 1), "MSIE") || Regex.match?(~r/Trident.+rv:/, joined)) ->
          :ie

        first[:name] == "Opera" || last[:name] == "OPR" ->
          :opera

        Enum.any?(names, &contains(String.downcase(&1), "micromessenger")) ->
          :wechat

        "Vivaldi" in names ->
          :vivaldi

        "Chrome" in names || "CriOS" in names ->
          :chrome

        "iTunes" in names ->
          :itunes

        Enum.any?(
          ["PLAYSTATION 3", "PlayStation Vita", "PlayStation 4"],
          &contains(List.first(comments), &1)
        ) ->
          :playstation

        Enum.take(names, 3) == ["Podcast", "Addict", "-"] ->
          :podcast

        Enum.any?(products, fn p ->
          String.downcase(p.name) == "applewebkit" ||
              Enum.any?(p.comment || [], &Regex.match?(~r/\AAppleWebKit\/[0-9.]+/iu, &1))
        end) ->
          :webkit

        first[:name] == "Mozilla" ->
          :gecko

        Enum.any?(names, &(&1 in ["NSPlayer", "Windows-Media-Player", "WMFSDK"])) &&
            first[:version] not in ["4.1.0.3856", "7.10.0.3059", "7.0.0.1956"] ->
          :wmp

        "AppleCoreMedia" in names ->
          :apple

        "Lavf" in names || ("NSPlayer" in names && first[:version] == "4.1.0.3856") ->
          :lavf

        true ->
          :base
      end

    app =
      if kind in [:chrome, :vivaldi, :webkit, :itunes, :apple],
        do: Enum.find(products, &(&1.comment && &1.comment != [])),
        else: List.first(products)

    %{kind: kind, products: products, app: app, raw: raw}
  end

  defp products(raw, acc) do
    case Regex.run(matcher(), raw) do
      nil ->
        Enum.reverse(acc)

      [matched, name, version | captures] ->
        comment =
          if length(captures) > 1,
            do:
              captures
              |> Enum.at(1)
              |> String.split("; ")
              |> Enum.reverse()
              |> Enum.drop_while(&(&1 == ""))
              |> Enum.reverse(),
            else: nil

        p = %{name: name, version: version, comment: comment}

        products(
          strip(binary_part(raw, byte_size(matched), byte_size(raw) - byte_size(matched))),
          [p | acc]
        )
    end
  end

  defp strip(s), do: String.replace(s, ~r/\A[\x00\x09-\x0d ]+|[\x00\x09-\x0d ]+\z/, "")
  defp contains(nil, _), do: false
  defp contains(s, sub), do: String.contains?(s, sub)
  defp comments(a), do: (a.app && a.app.comment) || []
  defp at(a, n), do: Enum.at(comments(a), n)

  defp product(a, name),
    do: Enum.find(a.products, &(String.downcase(&1.name) == String.downcase(name)))

  defp pv(a, name) do
    case product(a, name) do
      nil -> nil
      p -> p.version
    end
  end

  defp base_version(a), do: a.app && a.app.version

  defp capture(regex, s, index \\ 1) do
    case Regex.run(regex, s || "") do
      nil -> nil
      m -> Enum.at(m, index)
    end
  end

  def browser(a) do
    case a.kind do
      :base ->
        a.app && a.app.name

      :edge ->
        "Edge"

      :ie ->
        "Internet Explorer"

      :opera ->
        "Opera"

      :wechat ->
        "Wechat Browser"

      :vivaldi ->
        "Vivaldi"

      :chrome ->
        if(product(a, "Iron"), do: "Iron", else: "Chrome")

      :itunes ->
        "iTunes"

      :podcast ->
        "Podcast Addict"

      :wmp ->
        "Windows Media Player"

      :apple ->
        "AppleCoreMedia"

      :lavf ->
        "libavformat"

      :gecko ->
        Enum.find(["PaleMoon", "Firefox", "Camino", "Iceweasel", "Seamonkey"], &product(a, &1)) ||
          (a.app && a.app.name)

      :webkit ->
        cond do
          contains(webkit_os(a), "Android") -> "Android"
          webkit_platform(a) == "BlackBerry" -> "BlackBerry"
          true -> "Safari"
        end

      :playstation ->
        cond do
          contains(at(a, 0), "PLAYSTATION 3") -> "PS3 Internet Browser"
          List.last(a.products).name == "Silk" -> "Silk"
          contains(at(a, 0), "PlayStation 4") -> "PS4 Internet Browser"
          true -> nil
        end
    end
  end

  def version(a) do
    case a.kind do
      k when k in [:base, :wmp, :apple] ->
        base_version(a)

      k when k in [:edge, :vivaldi] ->
        List.last(a.products).version

      :ie ->
        capture(~r/(MSIE\s|rv:)([0-9.]+)/, Enum.join(comments(a), "; "), 2) || ""

      :chrome ->
        pv(a, "CriOS") || pv(a, "Chrome") || raise KeyError

      :wechat ->
        pv(a, "MicroMessenger") || raise KeyError

      :itunes ->
        pv(a, "iTunes") || raise KeyError

      :gecko ->
        case pv(a, browser(a)) do
          nil -> raise KeyError
          "" -> base_version(a)
          v -> v
        end

      :podcast ->
        nil

      :lavf ->
        if(product(a, "NSPlayer"), do: nil, else: base_version(a))

      :opera ->
        if opera_mini?(a),
          do: capture(~r/Opera Mini\/([0-9.]+)/, Enum.join(comments(a), "; ")) || "",
          else: pv(a, "Version") || pv(a, "OPR") || base_version(a)

      :playstation ->
        if browser(a) == "Silk",
          do: List.last(a.products).version,
          else:
            os(a) &&
              List.last(
                String.split(
                  os(a),
                  case platform(a) do
                    "PlayStation 3" -> "PLAYSTATION 3 "
                    p -> p <> " "
                  end
                )
              )

      :webkit ->
        pv(a, "Version") ||
          if(browser(a) == "Safari", do: capture(~r/iOS ([0-9.]+)/, webkit_os(a))) ||
          @builds[
            pv(a, "AppleWebKit") ||
              Enum.find_value(comments_all(a), &capture(~r/\AAppleWebKit\/([0-9.]+)/iu, &1))
          ] || ""
    end
  end

  def platform(a) do
    first = at(a, 0)
    cs = comments(a)

    case a.kind do
      k when k in [:base, :lavf] ->
        nil

      k when k in [:edge, :ie, :wmp] ->
        "Windows"

      k when k in [:opera, :apple] ->
        if contains(first, "Windows"), do: "Windows", else: first

      :wechat ->
        cond do
          contains(first, "iPhone") -> "iPhone"
          Enum.any?(cs, &contains(&1, "Android")) -> "Android"
          true -> first
        end

      k when k in [:chrome, :vivaldi] ->
        cond do
          contains(first, "Windows") -> "Windows"
          Enum.any?(cs, &contains(&1, "CrOS")) -> "ChromeOS"
          Enum.any?(cs, &contains(&1, "Android")) -> "Android"
          true -> first
        end

      k when k in [:webkit, :itunes] ->
        webkit_platform(a)

      :gecko ->
        cond do
          first in ["compatible", "Mobile"] -> nil
          first && String.starts_with?(first, "Windows ") -> "Windows"
          true -> first
        end

      :playstation ->
        Enum.find(["PlayStation 3", "PlayStation 4", "PlayStation Vita"], fn p ->
          contains(os(a), if(p == "PlayStation 3", do: "PLAYSTATION 3", else: p))
        end)

      :podcast ->
        if contains(os(a) || raise(KeyError), "Android"), do: "Android", else: nil
    end
  end

  defp webkit_platform(a) do
    cond do
      contains(at(a, 0), "Windows") -> "Windows"
      at(a, 0) == "BB10" -> "BlackBerry"
      Enum.any?(comments(a), &contains(&1, "Android")) -> "Android"
      true -> at(a, 0)
    end
  end

  defp common_os(a) do
    pick =
      cond do
        contains(at(a, 0), "Windows NT") -> at(a, 0)
        is_nil(at(a, 2)) || contains(at(a, 1), "Android") -> at(a, 1)
        true -> at(a, 2)
      end

    normalize_os(pick)
  end

  defp webkit_os(a) do
    pick =
      cond do
        contains(at(a, 0), "Windows NT") ->
          at(a, 0)

        is_nil(at(a, 2)) || contains(at(a, 1), "Android") ->
          at(a, 1)

        true ->
          Enum.find(
            comments(a),
            &capture(~r/CPU (?:iPhone |iPod )?OS ([0-9_]+) like Mac OS X/, &1)
          ) || at(a, 2)
      end

    normalize_os(pick)
  end

  def os(a) do
    case a.kind do
      k when k in [:base, :lavf] ->
        nil

      :edge ->
        normalize_os(
          Enum.find_value(
            comments_all(a),
            &capture(~r/(Windows NT [0-9.]+|Windows Phone (?:OS )?[0-9.]+)/, &1)
          ) || ""
        )

      :ie ->
        normalize_os(
          capture(
            ~r/(Windows NT [0-9.]+|Windows Phone (?:OS )?[0-9.]+)/,
            Enum.join(comments(a), "; ")
          ) || ""
        )

      :opera ->
        if contains(at(a, 0), "Windows"), do: normalize_os(at(a, 0)), else: at(a, 1)

      k when k in [:chrome, :vivaldi, :wechat, :apple] ->
        common_os(a)

      :webkit ->
        webkit_os(a)

      :itunes ->
        if contains(at(a, 0), "Windows"),
          do:
            Enum.find(
              ["Windows 8.1", "Windows 8", "Windows 7", "Windows Vista", "Windows XP"],
              &contains(at(a, 1), &1)
            ) || "Windows",
          else: webkit_os(a)

      :playstation ->
        if a.app && a.app.comment, do: Enum.join(comments(a), " "), else: nil

      :gecko ->
        index =
          cond do
            at(a, 1) == "U" ->
              2

            at(a, 0) &&
                (String.starts_with?(at(a, 0), "Windows ") ||
                   String.starts_with?(at(a, 0), "Android")) ->
              0

            at(a, 0) == "Mobile" ->
              nil

            true ->
              1
          end

        if index, do: normalize_os(at(a, index)), else: nil

      :podcast ->
        case Enum.at(a.products, 3) do
          %{name: n, comment: c} when n in ["Dalvik", "Mozilla"] ->
            cond do
              is_nil(c) -> raise KeyError
              length(c) > 3 -> Enum.at(c, 2)
              length(c) == 3 -> "Android"
              true -> nil
            end

          _ ->
            nil
        end

      :wmp ->
        wmp_os(a)
    end
  end

  def normalize_os(nil), do: nil

  def normalize_os(s) do
    cond do
      Map.has_key?(@windows, String.replace_prefix(s, "Windows NT ", "")) ->
        @windows[String.replace_prefix(s, "Windows NT ", "")]

      Regex.match?(~r/(?:Intel|PPC) Mac OS X/, s) ->
        "OS X" <>
          case capture(~r/(?:Intel|PPC) Mac OS X\s*([0-9_.]+)?/, s) do
            v when v in [nil, ""] -> ""
            v -> " " <> String.replace(v, "_", ".")
          end

      v = capture(~r/CPU (?:iPhone |iPod )?OS ([0-9_]+) like Mac OS X/, s) ->
        "iOS " <> String.replace(v, "_", ".")

      v = capture(~r/CrOS\s[^\s]+\s([0-9]+(?:\.[0-9]+)*)/, s) ->
        "ChromeOS " <> v

      true ->
        s
    end
  end

  defp wmp_os(a) do
    parts = version_parts(base_version(a))
    major = List.first(parts)
    if is_nil(major), do: raise(KeyError)
    unless is_integer(major), do: raise(ArgumentError)
    b = Enum.at(parts, 3)

    cond do
      major <= 4 ->
        case b do
          v when v in [3564, 3925] -> "Windows 98"
          3857 -> "Windows 9x"
          3936 -> "Windows XP"
          3938 -> "Windows 2000"
          _ -> "Windows"
        end

      major == 7 ->
        if b == 3055, do: "Windows 98", else: "Windows"

      major == 8 ->
        "Windows XP"

      major in [9, 10] ->
        case b do
          2980 -> "Windows 98/2000"
          v when v in [3268, 3367, 3270] -> "Windows 2000"
          v when v in [3802, 4503] -> "Windows XP"
          _ -> "Windows"
        end

      major in [11, 12] ->
        case Enum.at(parts, 2) do
          v when v in [9841, 9858, 9860, 9879] -> "Windows 10"
          9651 -> "Windows Phone 8.1"
          9600 -> "Windows 8.1"
          9200 -> "Windows 8"
          v when v in [7600, 7601] -> "Windows 7"
          v when v in [6000, 6001, 6002] -> "Windows Vista"
          5721 -> "Windows XP"
          _ -> "Windows"
        end

      true ->
        "Windows"
    end
  end

  defp comments_all(a), do: Enum.flat_map(a.products, &(&1.comment || []))
  defp opera_mini?(a), do: contains(Enum.join(comments(a), "; "), "Opera Mini")

  def bot?(a),
    do:
      is_nil(a.app) || Enum.any?(comments_all(a), &contains(String.downcase(&1), "bot")) ||
        !is_nil(product(a, "Chrome-Lighthouse")) || contains(a.app.name, "bot")

  def mobile?(a) do
    case a.kind do
      :opera ->
        opera_mini?(a)

      :playstation ->
        platform(a) == "PlayStation Vita"

      :podcast ->
        true

      :wmp ->
        os(a) in ["Windows Phone 8", "Windows Phone 8.1"]

      _ ->
        !is_nil(product(a, "Mobile")) || "Mobile" in comments_all(a) || contains(os(a), "Android") ||
          Enum.any?(comments(a), &String.starts_with?(&1, "IEMobile"))
    end
  end

  def version_nil?(v), do: Regex.match?(~r/\A\s*\z/, v || "")
  defp comparable?(v), do: Regex.match?(~r/\A[0-9]+(?:\.|\z)/, v || "")

  def version_parts(v) do
    cond do
      version_nil?(v) ->
        []

      comparable?(v) ->
        Regex.scan(~r/[0-9]+|[A-Za-z][0-9A-Za-z-]*\z/, v)
        |> Enum.map(fn [s] ->
          if Regex.match?(~r/\A[0-9]+\z/, s), do: String.to_integer(s), else: s
        end)

      true ->
        [v]
    end
  end

  def version_compare(a, b) do
    if comparable?(a) do
      left = version_parts(a)
      right = version_parts(b)

      Enum.reduce_while(0..5, 0, fn i, _ ->
        x = Enum.at(left, i, 0)
        y = Enum.at(right, i, 0)

        cmp =
          cond do
            is_binary(x) && is_integer(y) -> -1
            is_integer(x) && is_binary(y) -> 1
            x == y -> 0
            x < y -> -1
            true -> 1
          end

        if cmp == 0, do: {:cont, 0}, else: {:halt, cmp}
      end)
    else
      if a == b, do: 0, else: -1
    end
  end
end
