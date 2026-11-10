defmodule BasaTma.AuthTest do
  use ExUnit.Case, async: true
  alias BasaTma.Auth

  @token "123456:TEST-TOKEN"

  defp sign(params, secret) do
    check = params |> Enum.sort() |> Enum.map_join("\n", fn {k, v} -> "#{k}=#{v}" end)

    Map.put(
      params,
      "hash",
      :crypto.mac(:hmac, :sha256, secret, check) |> Base.encode16(case: :lower)
    )
  end

  defp init_data(params),
    do: params |> sign(:crypto.mac(:hmac, :sha256, "WebAppData", @token)) |> URI.encode_query()

  setup do
    user = Jason.encode!(%{id: 42, first_name: "Olena", username: "olena", language_code: "uk"})
    %{user: user, now: System.system_time(:second)}
  end

  test "accepts genuine Mini App data", %{user: user, now: now} do
    data = init_data(%{"auth_date" => "#{now}", "query_id" => "q1", "user" => user})
    assert {:ok, %{"id" => 42}} = Auth.verify_init_data(data, @token)
  end

  test "rejects tampered and expired Mini App data", %{user: user, now: now} do
    data = init_data(%{"auth_date" => "#{now}", "user" => user})
    assert {:error, :invalid} = Auth.verify_init_data(String.replace(data, "42", "43"), @token)
    assert {:error, :invalid} = Auth.verify_init_data(data, "other:token")

    old = init_data(%{"auth_date" => "#{now - 90_000}", "user" => user})
    assert {:error, :expired} = Auth.verify_init_data(old, @token)
  end

  test "verifies Login Widget data", %{now: now} do
    params =
      sign(
        %{"id" => "42", "first_name" => "Olena", "auth_date" => "#{now}"},
        :crypto.hash(:sha256, @token)
      )

    assert {:ok, _} = Auth.verify_login_widget(params, @token)
    assert {:error, :invalid} = Auth.verify_login_widget(%{params | "id" => "1"}, @token)
  end

  test "signs initData that verifies" do
    data = Auth.sign_init_data(%{id: 7, first_name: "Max"}, @token)
    assert {:ok, %{"id" => 7}} = Auth.verify_init_data(data, @token)
    assert {:error, :invalid} = Auth.verify_init_data(data, "other:token")
  end

  test "a Telegram user as plain attributes" do
    assert %{telegram_id: 42, display_name: "Olena K", language_code: "uk"} =
             Auth.user_attrs(%{
               "id" => 42,
               "first_name" => "Olena",
               "last_name" => "K",
               "language_code" => "uk"
             })

    assert %{display_name: "bob", telegram_username: "bob"} =
             Auth.user_attrs(%{"id" => "1", "username" => "bob"})
  end
end
