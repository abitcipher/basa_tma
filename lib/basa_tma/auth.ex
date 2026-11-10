defmodule BasaTma.Auth do
  @moduledoc """
  Verifies Telegram's signatures before a Telegram identity is trusted.

  * Mini App: `initData`, signed with
    HMAC-SHA256(key: HMAC-SHA256("WebAppData", bot token)).
  * Login Widget: fields signed with HMAC-SHA256(key: SHA-256(bot token)).

  Both reject data older than `:max_age` seconds (one day by default).
  """

  @max_age 86_400

  @doc "Verifies Mini App `initData` (a query string): `{:ok, telegram_user}`."
  @spec verify_init_data(String.t(), String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, :invalid | :expired}
  def verify_init_data(init_data, token, opts \\ []) when is_binary(init_data) do
    params = URI.decode_query(init_data)

    with :ok <- check_hash(params, webapp_secret(token)),
         :ok <- check_age(params, opts),
         {:ok, user} <- Jason.decode(params["user"] || "") do
      {:ok, user}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid}
      error -> error
    end
  end

  @doc "Verifies Login Widget fields (a map of strings): `{:ok, fields}`."
  @spec verify_login_widget(map(), String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, :invalid | :expired}
  def verify_login_widget(params, token, opts \\ []) when is_map(params) do
    secret = :crypto.hash(:sha256, token || "")

    with :ok <- check_hash(params, secret),
         :ok <- check_age(params, opts) do
      {:ok, params}
    end
  end

  @doc """
  `initData` for `user`, signed the way Telegram signs it. For emulators and
  tests.
  """
  @spec sign_init_data(map(), String.t(), keyword()) :: String.t()
  def sign_init_data(user, token, opts \\ []) do
    params = %{
      "auth_date" => Integer.to_string(Keyword.get(opts, :now, System.system_time(:second))),
      "query_id" => Keyword.get(opts, :query_id, "Q#{System.unique_integer([:positive])}"),
      "user" => Jason.encode!(user)
    }

    params |> Map.put("hash", hash(params, webapp_secret(token))) |> URI.encode_query()
  end

  @doc """
  A verified Telegram user as plain attributes: `:telegram_id`,
  `:telegram_username`, `:display_name`, `:language_code`.
  """
  def user_attrs(user) do
    name =
      [user["first_name"], user["last_name"]] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")

    %{
      telegram_id: to_int(user["id"]),
      telegram_username: user["username"],
      display_name: if(name == "", do: user["username"], else: name),
      language_code: user["language_code"]
    }
  end

  defp webapp_secret(token), do: :crypto.mac(:hmac, :sha256, "WebAppData", token || "")

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  defp hash(params, secret) do
    check_string =
      params
      |> Map.drop(["hash", "signature"])
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("\n", fn {k, v} -> "#{k}=#{v}" end)

    :crypto.mac(:hmac, :sha256, secret, check_string) |> Base.encode16(case: :lower)
  end

  defp check_hash(%{"hash" => hash} = params, secret) do
    if Plug.Crypto.secure_compare(hash(params, secret), String.downcase(hash)),
      do: :ok,
      else: {:error, :invalid}
  end

  defp check_hash(_, _), do: {:error, :invalid}

  defp check_age(params, opts) do
    max_age = Keyword.get(opts, :max_age, @max_age)
    now = Keyword.get(opts, :now, System.system_time(:second))

    case Integer.parse(params["auth_date"] || "") do
      {auth_date, ""} when now - auth_date <= max_age -> :ok
      {_, ""} -> {:error, :expired}
      _ -> {:error, :invalid}
    end
  end
end
