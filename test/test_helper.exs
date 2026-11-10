{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: BasaTma.Test.PubSub},
      BasaTma.Test.Endpoint,
      ExGram,
      BasaTma.Emulator,
      {BasaTma.Test.Bot, [method: :test, token: BasaTma.Emulator.token(), handler_mode: :sync]}
    ],
    strategy: :one_for_one
  )

ExUnit.start()
