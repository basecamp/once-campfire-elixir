defmodule Campfire.Release do
  @moduledoc """
  Values fixed for the life of the release, read from the environment once rather than on
  every response: the version and revision headers and the VAPID public key every page carries.
  """

  def version, do: cached(:version, fn -> System.get_env("APP_VERSION", "dev") end)
  def revision, do: cached(:revision, fn -> System.get_env("GIT_REVISION", "dev") end)

  def vapid_public_key,
    do:
      cached(:vapid, fn -> Campfire.Assets.html_escape(System.get_env("VAPID_PUBLIC_KEY", "")) end)

  defp cached(name, read) do
    case :persistent_term.get({__MODULE__, name}, nil) do
      nil ->
        value = read.()
        :persistent_term.put({__MODULE__, name}, value)
        value

      value ->
        value
    end
  end
end
