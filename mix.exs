defmodule BasaTma.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :basa_tma,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: "Telegram Mini App toolkit for Phoenix: sign-in, app shell, local emulator",
      source_url: "https://github.com/abitcipher/basa_tma"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application, do: [extra_applications: [:logger, :crypto]]

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.2"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug_crypto, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:ex_gram, "~> 0.71"},
      {:req, "~> 0.5"},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end
end
