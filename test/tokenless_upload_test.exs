defmodule Campfire.TokenlessUploadTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test
  alias Campfire.{Auth, DB, Endpoint, Storage}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    DB.restore_fixture(@fixture)
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    cookie = Auth.start_session(conn(:get, "/"), user).resp_cookies["session_token"].value
    %{user: user, cookie: cookie}
  end

  test "token-free creation and signed authenticated disk PUT keep distinct protections",
       context do
    body = "token-free-upload"

    payload =
      Jason.encode!(%{
        "blob" => %{
          "filename" => "upload.txt",
          "byte_size" => byte_size(body),
          "checksum" => Base.encode64(:crypto.hash(:md5, body)),
          "content_type" => "text/plain"
        }
      })

    request =
      conn(:post, "https://campfire.test/rails/active_storage/direct_uploads", payload)
      |> put_req_header("content-type", "application/json")
      |> put_req_cookie("session_token", context.cookie)

    rejected = Endpoint.call(request, Endpoint.init([]))
    assert rejected.status == 422

    accepted =
      request
      |> put_req_header("sec-fetch-site", "same-origin")
      |> Endpoint.call(Endpoint.init([]))

    assert accepted.status == 200
    response = Jason.decode!(accepted.resp_body)
    upload_url = response["direct_upload"]["url"]
    blob = DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [response["id"]])
    on_exit(fn -> File.rm(Storage.path(blob["key"])) end)
    assert Jason.decode!(blob["metadata"])["campfire_upload_user_id"] == context.user["id"]

    upload =
      conn(:put, upload_url, body)
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("content-length", to_string(byte_size(body)))
      |> put_req_header("origin", "null")
      |> put_req_header("sec-fetch-site", "cross-site")

    assert Endpoint.call(upload, Endpoint.init([])).status == 401

    other =
      DB.one("SELECT * FROM users WHERE role != 2 AND status=0 AND id != ? LIMIT 1", [
        context.user["id"]
      ])

    other_cookie = Auth.start_session(conn(:get, "/"), other).resp_cookies["session_token"].value

    assert (upload
            |> put_req_cookie("session_token", other_cookie)
            |> Endpoint.call(Endpoint.init([]))).status == 403

    valid =
      upload
      |> put_req_cookie("session_token", context.cookie)
      |> Endpoint.call(Endpoint.init([]))

    assert valid.status == 204
    assert File.read!(Storage.path(blob["key"])) == body

    assert (conn(:put, upload_url <> "tampered", body)
            |> put_req_cookie("session_token", context.cookie)
            |> Endpoint.call(Endpoint.init([]))).status == 404
  end
end
