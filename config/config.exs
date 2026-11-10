import Config

if config_env() == :test do
  config :basa_tma, :emulator, pubsub: BasaTma.Test.PubSub, bot: :tma_test_bot, title: "Test bot"
  config :ex_gram, adapter: BasaTma.Emulator.Adapter

  config :basa_tma, BasaTma.Test.Endpoint,
    secret_key_base: String.duplicate("t", 64),
    live_view: [signing_salt: "tma-test-salt"],
    server: false

  config :phoenix, :json_library, Jason
  config :logger, level: :warning
end
