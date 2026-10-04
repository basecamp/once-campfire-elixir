defmodule Campfire.RailsTest do
  use ExUnit.Case, async: true
  alias Campfire.Rails
  @vectors Jason.decode!(File.read!("vectors/rails_compat.json"))
  for v <- @vectors["key_generator"] do
    @v v
    test "key #{@v["salt"]}" do
      assert Base.encode16(Rails.key(@v["salt"], @v["length"]), case: :lower) == @v["key_hex"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["signed_cookies"]["generate"]) do
    @v v
    test "signed_cookies generate #{index}" do
      assert Rails.sign_cookie(@v["name"], @v["value"], @v["expires_at"]) == @v["raw"],
             inspect(@v)
    end
  end

  for {v, index} <- Enum.with_index(@vectors["signed_cookies"]["verify"]) do
    @v v
    test "signed_cookies verify #{index}" do
      {:ok, now, _} = DateTime.from_iso8601(@v["now"])
      assert Rails.verify_cookie(@v["name"], @v["raw"], now) == @v["expected"], inspect(@v)
    end
  end

  for {v, index} <- Enum.with_index(@vectors["encrypted_cookies"]["verify"]) do
    @v v
    test "encrypted_cookies verify #{index}" do
      {:ok, now, _} = DateTime.from_iso8601(@v["now"])
      assert Rails.decrypt_cookie(@v["name"], @v["raw"], now) == @v["expected"], inspect(@v)
    end
  end

  for {v, index} <- Enum.with_index(@vectors["signed_ids"]["generate"]) do
    @v v
    test "signed_ids generate #{index}" do
      assert Rails.signed_id(@v["model"], @v["id"], @v["purpose"], @v["expires_at"]) ==
               @v["signed_id"],
             inspect(@v)
    end
  end

  for {v, index} <- Enum.with_index(@vectors["signed_ids"]["verify"]) do
    @v v
    test "signed_ids verify #{index}" do
      {:ok, now, _} = DateTime.from_iso8601(@v["now"])

      assert Rails.verify_id(@v["model"], @v["signed_id"], @v["purpose"], now) == @v["expected"],
             inspect(@v)
    end
  end

  test "global CSRF key" do
    assert Base.encode16(Rails.csrf_global(@vectors["csrf"]["session_token"]), case: :lower) ==
             @vectors["csrf"]["global_token_hex"]
  end

  for {v, index} <- Enum.with_index(@vectors["csrf"]["form_tokens"]) do
    @v v
    test "CSRF form #{index}" do
      assert Base.encode16(
               Rails.csrf_form(
                 @vectors["csrf"]["session_token"],
                 @v["normalized_action_path"],
                 @v["method"]
               ),
               case: :lower
             ) == @v["unmasked_hex"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["csrf"]["validity"]) do
    @v v
    test "CSRF validity #{index}" do
      assert Rails.csrf_valid?(
               @v["token"],
               @vectors["csrf"]["session_token"],
               @v["path"],
               @v["method"]
             ) == @v["expected"],
             inspect(@v)
    end
  end

  for {v, index} <- Enum.with_index(@vectors["passwords"]["checks"]) do
    @v v
    test "bcrypt #{index}" do
      assert Bcrypt.verify_pass(@v["password"], @v["digest"]) == @v["expected"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["app_verifiers"]["generate"]) do
    @v v
    test "app verifier generation #{index}" do
      assert Rails.sign_message(@v["name"], @v["data_json"], @v["purpose"], @v["expires_at"]) ==
               @v["message"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["app_verifiers"]["verify"]) do
    @v v
    test "app verifier verification #{index}" do
      {:ok, now, _} = DateTime.from_iso8601(@v["now"])
      value = Rails.verify_message(@v["name"], @v["message"], @v["purpose"], now)
      expected = if @v["expected_json"], do: Jason.decode!(@v["expected_json"]), else: nil
      assert value == expected
    end
  end

  for {v, index} <- Enum.with_index(@vectors["turbo_stream_names"]["generate"]) do
    @v v
    test "Turbo stream generation #{index}" do
      assert Rails.sign_stream(@v["stream_name"]) == @v["signed"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["turbo_stream_names"]["verify"]) do
    @v v
    test "Turbo stream verification #{index}" do
      assert Rails.verify_stream(@v["signed"]) == @v["expected"]
    end
  end
end
