defmodule BasaTma.Emulator.Adapter do
  @moduledoc "ExGram adapter that answers Bot API calls from `BasaTma.Emulator`."
  @behaviour ExGram.Adapter

  @impl true
  def request(_verb, path, body, _opts) do
    method = path |> String.split("/") |> List.last()
    {:ok, BasaTma.Emulator.api(method, decode(body))}
  end

  defp decode(body) when is_map(body), do: body
  defp decode(body) when is_list(body), do: Map.new(body)
  defp decode(_), do: %{}
end
