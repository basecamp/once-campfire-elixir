defmodule Campfire.JSON do
  @moduledoc """
  JSON through Torque, falling back to Jason only for ordered objects.

  Torque encodes the same bytes as Jason for everything this app produces except
  exponent-form floats, and decodes about three times faster. Ordered objects have to stay on
  Jason: Torque decodes objects into maps and its proplist encoding takes keyword keys, while
  Active Storage metadata envelopes carry binary keys that must keep their order to match the
  reference byte for byte.
  """

  defmodule Error do
    @moduledoc "Raised when a JSON document cannot be decoded."
    defexception [:message]
  end

  @doc "Decodes JSON, returning `{:ok, term}` or `{:error, reason}`."
  def decode(json), do: Torque.decode(json)

  @doc "Decodes JSON, raising `Campfire.JSON.Error` on malformed input."
  def decode!(json) do
    Torque.decode!(json)
  rescue
    error in [ArgumentError] -> reraise Error, [message: Exception.message(error)], __STACKTRACE__
  end

  @doc "Encodes an ordered object, which Torque cannot express, with the same bytes as Torque."
  def encode_ordered(%Jason.OrderedObject{} = object), do: Jason.encode!(object)

  @doc "Decodes a JSON object preserving key order, returning `{:ok, term}` or `{:error, reason}`."
  def decode_ordered(json), do: Jason.decode(json, objects: :ordered_objects)

  @doc "Decodes a JSON object preserving key order, raising on malformed input."
  def decode_ordered!(json), do: Jason.decode!(json, objects: :ordered_objects)
end
