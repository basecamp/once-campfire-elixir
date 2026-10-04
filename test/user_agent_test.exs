defmodule Campfire.UserAgentTest do
  use ExUnit.Case, async: true
  alias Campfire.{Platform, UserAgent}
  @vectors Jason.decode!(File.read!("vectors/campfire_user_agents.json"))
  defp safe(fun) do
    fun.()
  rescue
    KeyError -> %{"error" => "NoMethodError"}
    ArgumentError -> %{"error" => "ArgumentError"}
  end

  for {row, i} <- Enum.with_index(@vectors["user_agents"]) do
    @row row
    test "captured Rails user agent #{i}" do
      a = UserAgent.parse(@row["ua"])

      for {field, fun} <- [
            {"browser", &UserAgent.browser/1},
            {"version", &UserAgent.version/1},
            {"platform", &UserAgent.platform/1},
            {"os", &UserAgent.os/1},
            {"bot", &UserAgent.bot?/1},
            {"mobile", &UserAgent.mobile?/1}
          ] do
        assert safe(fn -> fun.(a) end) == @row[field], "#{inspect(@row["ua"])} #{field}"
      end

      assert safe(fn -> Platform.blocked?(@row["ua"]) end) == @row["blocked"]
      expected = @row["application_platform"]

      for {field, value} <- expected do
        assert safe(fn -> Platform.value(@row["ua"], field) end) == value,
               "#{inspect(@row["ua"])} platform #{field}"
      end
    end
  end

  test "captured Ruby versions and comparisons" do
    for row <- @vectors["versions"] do
      assert UserAgent.version_nil?(row["string"]) == row["nil"]

      assert Enum.map(UserAgent.version_parts(row["string"]), fn p ->
               if is_integer(p), do: "i:#{p}", else: "s:#{p}"
             end) == row["to_a"]
    end

    for row <- @vectors["comparisons"] do
      assert UserAgent.version_compare(row["a"], row["b"]) == row["cmp"], inspect(row)
      assert row["a"] == row["b"] == row["eq"]
    end
  end
end
