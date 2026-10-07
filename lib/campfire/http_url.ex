defmodule Campfire.HttpURL do
  @moduledoc "URI::HTTP input grammar before any resolver or transport side effects."

  def parse(url) when is_binary(url) do
    if Regex.match?(~r/[^\x21-\x7E]|[\\<>"`{}|^]|%(?![0-9a-fA-F]{2})/, url) do
      {:error, :invalid_url}
    else
      uri = URI.parse(url)
      scheme = String.downcase(uri.scheme || "")
      authority = uri |> Map.from_struct() |> Map.get(:authority) || ""

      port =
        if String.contains?(authority, "]"),
          do: List.last(String.split(authority, "]")),
          else: List.last(String.split(authority, "@"))

      invalid_port = Regex.match?(~r/:[^0-9:]+\z/, port)

      invalid_path =
        Regex.match?(~r/[\[\]]/, (uri.path || "") <> (uri.query || "") <> (uri.fragment || ""))

      if scheme in ["http", "https"] && !invalid_port && !invalid_path do
        {:ok, %{uri | scheme: scheme}}
      else
        {:error, :invalid_url}
      end
    end
  rescue
    _ -> {:error, :invalid_url}
  end

  def parse(_), do: {:error, :invalid_url}
end
