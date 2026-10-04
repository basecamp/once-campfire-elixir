Code.require_file("support/richtext_comparison.ex", __DIR__)

defmodule Campfire.RichTextCorpusTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, Mentions, MessagesView, RichText, RichTextComparison}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  @corpus Jason.decode!(File.read!("vectors/richtext-corpus.json"))

  test "differential stored rich-text corpus" do
    DB.restore_fixture(@fixture)

    for user <- @corpus["users"] do
      attrs = user["attributes"]
      fields = Map.keys(attrs)

      DB.query(
        "INSERT INTO users (#{Enum.join(fields, ",")}) VALUES (#{Enum.map_join(fields, ",", fn _ -> "?" end)})",
        Enum.map(fields, &attrs[&1])
      )
    end

    comparisons =
      Enum.flat_map(@corpus["cases"], fn vector ->
        Process.put(:campfire_request_host, vector["host"])

        actual = %{
          "presentation" => outcome(fn -> MessagesView.presentation(vector["body"]) end),
          "plain_text" => outcome(fn -> RichText.plain_text(vector["body"]) end),
          "mentioned" => outcome(fn -> Enum.map(Mentions.users(vector["body"]), & &1["id"]) end)
        }

        for key <- ~w(presentation plain_text mentioned), actual[key] != vector[key] do
          %{
            "name" => vector["name"],
            "body" => vector["body"],
            "field" => key,
            "expected" => vector[key],
            "actual" => actual[key]
          }
        end
      end)

    File.write!(
      "parity/results/richtext-corpus-raw-differences.json",
      Jason.encode!(comparisons, pretty: true)
    )

    differences =
      Enum.reject(comparisons, fn row -> compare(row["field"], row["actual"], row["expected"]) end)

    File.write!(
      "parity/results/richtext-corpus-differences.json",
      Jason.encode!(differences, pretty: true)
    )

    assert differences == [],
           "#{length(differences)} rich-text differences; see parity/results/richtext-corpus-differences.json"
  end

  defp compare("presentation", actual, expected),
    do:
      RichTextComparison.comparable(actual) ==
        expected |> RichTextComparison.presentation() |> RichTextComparison.comparable()

  defp compare(_, actual, expected),
    do: RichTextComparison.comparable(actual) == RichTextComparison.comparable(expected)

  defp outcome(fun) do
    %{"ok" => fun.()}
  rescue
    error -> %{"error" => inspect(error.__struct__), "message" => Exception.message(error)}
  end
end
