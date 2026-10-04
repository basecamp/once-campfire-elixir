defmodule Campfire.Params do
  defmodule Missing do
    defexception [:message, plug_status: 400]
  end

  def string(nil), do: nil
  def string(true), do: "t"
  def string(false), do: "f"
  def string(value) when is_binary(value), do: value
  def string(value) when is_number(value), do: to_string(value)

  def permit(attrs, names, hashes \\ []) do
    Map.take(attrs, names ++ hashes)
    |> Map.reject(fn {key, value} ->
      cond do
        key in hashes -> !is_map(value) || is_struct(value)
        match?(%Plug.Upload{}, value) -> false
        true -> is_map(value) || is_list(value)
      end
    end)
  end

  def required(params, key) do
    value = params[key]

    if value in [nil, false, "", [], %{}] || (is_binary(value) && String.trim(value) == "") do
      raise Missing, message: "parameter missing: #{key}"
    end

    if !is_map(value), do: raise(ArgumentError, "nested parameters must be an object")
    value
  end
end
