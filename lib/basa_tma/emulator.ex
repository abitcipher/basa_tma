defmodule BasaTma.Emulator do
  @moduledoc """
  A local stand-in for Telegram, for development without a bot token or a
  public HTTPS server.

  Your real ExGram bot runs unchanged: updates are pushed into it (ExGram's
  `:test` updates method) and its Bot API calls go to
  `BasaTma.Emulator.Adapter`, which records them here.
  `BasaTma.Emulator.Live` shows each chat and lets you act as any Telegram
  user.

  ## Setup

      # config
      config :basa_tma, :emulator, pubsub: MyApp.PubSub, bot: :my_bot
      config :ex_gram, adapter: BasaTma.Emulator.Adapter

      # supervision tree
      ExGram,
      BasaTma.Emulator,
      {MyApp.Bot, [method: :test, token: BasaTma.Emulator.token(), handler_mode: :sync]}

  Options of `:emulator`: `:pubsub` and `:bot` (the ExGram bot's name) are
  required; `:title`, `:icon`, `:menu_path`, `:commands`, `:file_path` and
  `:users` adjust the chat page (see `BasaTma.Emulator.Live`).
  """
  use GenServer

  @token "000000:TMA-EMULATOR"
  @bot_username "tma_emulator_bot"

  def token, do: @token
  def bot_username, do: @bot_username

  def config, do: Application.get_env(:basa_tma, :emulator) || []
  def enabled?, do: config() != []

  def topic(chat_id), do: "tma_emulator:#{chat_id}"

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "All entries of a chat, oldest first."
  def transcript(chat_id), do: GenServer.call(__MODULE__, {:transcript, chat_id})

  def reset(chat_id), do: GenServer.call(__MODULE__, {:reset, chat_id})

  @doc """
  The user sends something to the bot. `content` is `{:text, text}`,
  `{:photo, binary, mime}` or `{:contact, phone}`; `reply_to` is a message
  id in this chat. Returns after the bot has handled it.
  """
  def user_sends(user, content, reply_to \\ nil) do
    update = GenServer.call(__MODULE__, {:user_message, user, content, reply_to})
    ExGram.Updates.Test.push_update(Keyword.fetch!(config(), :bot), update)
  end

  @doc "Bytes of a file the user sent: `{:ok, binary, mime}`."
  def file(file_id), do: GenServer.call(__MODULE__, {:file, file_id})

  @doc "Answers a Bot API request (called by the adapter)."
  def api(method, body), do: GenServer.call(__MODULE__, {:api, method, body})

  @doc "Mini App `initData` for `user`, signed like Telegram signs it."
  def init_data(user), do: BasaTma.Auth.sign_init_data(user_json(user), @token)

  @impl true
  def init(:ok), do: {:ok, %{next_id: 1, update_id: 1, chats: %{}, files: %{}}}

  @impl true
  def handle_call({:transcript, chat_id}, _from, state) do
    {:reply, state.chats |> Map.get(chat_id, []) |> Enum.reverse(), state}
  end

  def handle_call({:reset, chat_id}, _from, state) do
    {:reply, :ok, put_in(state.chats[chat_id], [])}
  end

  def handle_call({:file, file_id}, _from, state) do
    reply = with {bin, mime} <- state.files[file_id], do: {:ok, bin, mime}
    {:reply, reply || {:error, :not_found}, state}
  end

  def handle_call({:user_message, user, content, reply_to}, _from, state) do
    id = state.next_id
    chat = chat_json(user)

    {message, entry, state} =
      case content do
        {:text, text} ->
          {%{text: text}, %{text: text}, state}

        {:photo, bin, mime} ->
          file_id = "EMUFILE#{id}"

          size = %{
            file_id: file_id,
            file_unique_id: file_id,
            width: 1024,
            height: 768,
            file_size: byte_size(bin)
          }

          {%{photo: [size]}, %{photo: file_id}, put_in(state.files[file_id], {bin, mime})}

        {:contact, phone} ->
          contact = %{phone_number: phone, first_name: user.first_name, user_id: user.id}
          {%{contact: contact}, %{text: "📱 #{phone}"}, state}
      end

    reply_message = reply_to && find(state, user.id, reply_to)

    message =
      message
      |> Map.merge(%{message_id: id, date: now(), chat: chat, from: user_json(user)})
      |> then(fn m ->
        if reply_message,
          do:
            Map.put(m, :reply_to_message, %{
              message_id: reply_to,
              date: now(),
              chat: chat,
              text: reply_message.text
            }),
          else: m
      end)

    entry = Map.merge(entry, %{id: id, from: :user, reply_to: reply_to, at: DateTime.utc_now()})

    {:ok, update} =
      ExGram.Cast.cast(%{update_id: state.update_id, message: message}, ExGram.Model.Update)

    state =
      state
      |> record(user.id, entry)
      |> Map.merge(%{next_id: id + 1, update_id: state.update_id + 1})

    {:reply, update, state}
  end

  def handle_call({:api, method, body}, _from, state) do
    {result, state} = api_call(method, body, state)
    {:reply, result, state}
  end

  defp api_call("getMe", _body, state) do
    name = Keyword.get(config(), :title, "Bot")
    {%{id: 1, is_bot: true, first_name: name, username: @bot_username}, state}
  end

  defp api_call("sendMessage", body, state) do
    chat_id = to_int(body[:chat_id] || body["chat_id"])
    text = body[:text] || body["text"]
    id = state.next_id

    entry = %{
      id: id,
      from: :bot,
      text: text,
      reply_markup: normalize(body[:reply_markup] || body["reply_markup"]),
      at: DateTime.utc_now()
    }

    result = %{message_id: id, date: now(), chat: %{id: chat_id, type: "private"}, text: text}
    {result, state |> record(chat_id, entry) |> Map.put(:next_id, id + 1)}
  end

  defp api_call("getFile", body, state) do
    file_id = body[:file_id] || body["file_id"]
    {%{file_id: file_id, file_unique_id: file_id, file_path: "emulator/#{file_id}"}, state}
  end

  defp api_call(_method, _body, state), do: {true, state}

  defp record(state, chat_id, entry) do
    if pubsub = config()[:pubsub],
      do: Phoenix.PubSub.broadcast(pubsub, topic(chat_id), {:tma_emulator, entry})

    update_in(state, [:chats, Access.key(chat_id, [])], &[entry | &1])
  end

  defp find(state, chat_id, id),
    do: state.chats |> Map.get(chat_id, []) |> Enum.find(&(&1.id == id))

  defp normalize(nil), do: nil
  defp normalize(markup) when is_binary(markup), do: Jason.decode!(markup)
  defp normalize(%_{} = markup), do: markup |> ExGram.Adapter.encode() |> Jason.decode!()
  defp normalize(markup), do: markup |> Jason.encode!() |> Jason.decode!()

  defp chat_json(user), do: %{id: user.id, type: "private", first_name: user.first_name}

  defp user_json(user) do
    %{
      id: user.id,
      is_bot: false,
      first_name: user.first_name,
      last_name: user[:last_name],
      username: user[:username],
      language_code: user[:language_code] || "en"
    }
    |> Map.reject(fn {_, v} -> is_nil(v) end)
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  defp now, do: System.system_time(:second)
end
