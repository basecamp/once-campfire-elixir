defmodule Campfire.FetchMetadataTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test
  alias Campfire.{Auth, RequestURL}

  test "method, origin, metadata and TLS policy matrix" do
    original = System.get_env("FORCE_SSL")

    on_exit(fn ->
      if original, do: System.put_env("FORCE_SSL", original), else: System.delete_env("FORCE_SSL")
    end)

    for method <- ~w(GET HEAD POST PUT PATCH DELETE OPTIONS TRACE),
        scheme <- [:http, :https],
        forced <- [nil, "0", "false", "1", "true", "TRUE"],
        site <- [
          nil,
          "same-origin",
          "same-site",
          "cross-site",
          "none",
          "",
          "Same-Origin",
          "same-origin,same-site",
          "garbage"
        ],
        origin <- [nil, :matching, "null", "https://attacker.test"] do
      if forced, do: System.put_env("FORCE_SSL", forced), else: System.delete_env("FORCE_SSL")
      request = %{conn(method, "/session") | scheme: scheme, host: "campfire.test", port: 8443}
      actual_origin = if origin == :matching, do: Auth.base(request), else: origin
      request = if site, do: put_req_header(request, "sec-fetch-site", site), else: request

      request =
        if actual_origin, do: put_req_header(request, "origin", actual_origin), else: request

      expected =
        method in ~w(GET HEAD) or
          (origin in [nil, :matching] and
             (site in ["same-origin", "same-site"] or
                (is_nil(site) and scheme == :http and forced not in ["1", "true", "TRUE"])))

      assert Auth.request_allowed?(request) == expected,
             inspect({method, scheme, forced, site, origin})
    end
  end

  test "only the trusted local proxy changes the effective TLS origin" do
    request =
      conn(:post, "/session")
      |> put_req_header("x-forwarded-proto", "https")
      |> put_req_header("x-forwarded-host", "campfire.test:8443")

    trusted = RequestURL.call(%{request | remote_ip: {127, 0, 0, 1}}, [])
    assert Auth.base(trusted) == "https://campfire.test:8443"
    refute Auth.request_allowed?(trusted)
    assert Auth.request_allowed?(put_req_header(trusted, "sec-fetch-site", "same-origin"))

    refute Auth.request_allowed?(
             trusted
             |> put_req_header("sec-fetch-site", "same-site")
             |> put_req_header("origin", "https://campfire.test")
           )

    untrusted = RequestURL.call(%{request | remote_ip: {192, 0, 2, 1}}, [])
    assert untrusted.scheme == :http
    assert Auth.request_allowed?(untrusted)
  end

  test "duplicate metadata and origin headers are rejected" do
    request = conn(:post, "/")

    refute Auth.request_allowed?(%{
             request
             | req_headers: [{"sec-fetch-site", "same-origin"}, {"sec-fetch-site", "same-origin"}]
           })

    refute Auth.request_allowed?(%{
             request
             | req_headers: [
                 {"origin", Auth.base(request)},
                 {"origin", Auth.base(request)},
                 {"sec-fetch-site", "same-origin"}
               ]
           })
  end
end
