defmodule Campfire.Platform do
  alias Campfire.UserAgent

  @fields ~w(ios android mac chrome firefox safari edge apple_messages mobile desktop windows operating_system browser)
  def describe(raw), do: Map.new(@fields, &{&1, value(raw, &1)})

  def value(raw, field) do
    raw = raw || ""
    a = UserAgent.parse(raw)
    ios = String.contains?(raw, ["iPhone", "iPad"])
    android = String.contains?(raw, "Android")

    case field do
      "ios" ->
        ios

      "android" ->
        android

      "mac" ->
        String.contains?(raw, "Macintosh")

      "chrome" ->
        matches(UserAgent.browser(a), "Chrome")

      "firefox" ->
        matches(UserAgent.browser(a), ["Firefox", "FxiOS"])

      "safari" ->
        matches(UserAgent.browser(a), "Safari")

      "edge" ->
        matches(UserAgent.browser(a), "Edg")

      "apple_messages" ->
        String.contains?(String.downcase(raw), "facebookexternalhit") &&
          String.contains?(String.downcase(raw), "twitterbot")

      "mobile" ->
        ios || android

      "desktop" ->
        !(ios || android)

      "windows" ->
        operating_system(a) == "Windows"

      "operating_system" ->
        operating_system(a)

      "browser" ->
        UserAgent.browser(a)
    end
  end

  defp matches(nil, _), do: raise(KeyError)
  defp matches(s, names), do: String.contains?(s, names)

  def operating_system(a) do
    platform = UserAgent.platform(a) || ""

    mapping = [
      {"Android", "Android"},
      {"iPad", "iPad"},
      {"iPhone", "iPhone"},
      {"Macintosh", "macOS"},
      {"Windows", "Windows"},
      {"CrOS", "ChromeOS"}
    ]

    Enum.find_value(mapping, fn {pattern, name} ->
      if String.contains?(platform, pattern), do: name
    end) ||
      case UserAgent.os(a) do
        nil -> nil
        os -> if String.contains?(os, "Linux"), do: "Linux", else: os
      end
  end

  def blocked?(raw) do
    if String.trim(raw || "") == "" do
      false
    else
      a = UserAgent.parse(raw)
      version = UserAgent.version(a)

      if is_nil(version) || String.trim(version) == "" do
        false
      else
        browser = UserAgent.browser(a) || raise(KeyError)

        minimum =
          %{
            "safari" => "17.2",
            "chrome" => "120",
            "firefox" => "121",
            "opera" => "104",
            "internet explorer" => false
          }[String.downcase(browser)]

        !is_nil(minimum) && (minimum == false || UserAgent.version_compare(version, minimum) < 0) &&
          !UserAgent.bot?(a)
      end
    end
  end
end
