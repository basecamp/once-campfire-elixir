defmodule Campfire.RouteRecognitionTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, RouteRecognition}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  @routes Jason.decode!(File.read!("vectors/route-actions.json"))
  @samples Jason.decode!(File.read!("vectors/route-samples.json"))
  setup do
    DB.restore_fixture(@fixture)
    :ok
  end

  for {sample, index} <- Enum.with_index(@samples) do
    test "ordered route recognition #{index}" do
      sample = unquote(Macro.escape(sample))

      conn =
        Plug.Test.conn(sample["method"], sample["path"])
        |> Plug.Conn.fetch_query_params()
        |> RouteRecognition.call([])

      if conn.assigns[:rails_route] do
        route = conn.assigns.rails_route
        assert route["controller"] == sample["params"]["controller"]
        assert route["action"] == sample["params"]["action"]
      else
        assert conn.status in [404, 500]

        source =
          Enum.find(@routes, fn route ->
            route["controller"] == (sample["params"] || %{})["controller"] &&
              route["action"] == (sample["params"] || %{})["action"]
          end)

        assert sample["params"] == nil || source["status"] != "implemented"
      end
    end
  end
end
