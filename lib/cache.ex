defmodule AwsSigner.Cache do
  require Logger
  use Agent

  def start_link(_opts \\ []),
    do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def fetch(key, fallback \\ nil) do
    case Agent.get(__MODULE__, & &1) do
      %{^key => {value, nil}} ->
        hit(key, value, nil)

      %{^key => {value, t}} ->
        now = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        if now > t,
          do: miss(key, fallback),
        else: hit(key, value, t)

      %{} ->
        miss(key, fallback)
    end
  end

  def put(key, value, expire_at \\ nil) do
    :ok = Agent.update(__MODULE__, fn state -> Map.put(state, key, {value, expire_at}) end)
    {value, expire_at}
  end

  def delete(key) do
    :ok = Agent.update(__MODULE__, fn state -> Map.delete(state, key) end)
  end

  #
  # private
  #

  defp hit(key, value, expire_at) do
    Logger.debug("Cache hit: #{inspect(key)} (#{expire_at})")
    {:hit, {value, expire_at}}
  end

  defp miss(key, fallback) do
    Logger.debug("Cache miss: #{inspect(key)}")

    if is_function(fallback) do
      case fallback.() do
        {:ok, value, expire_at} ->
          {:miss, put(key, value, expire_at)}

        {:ok, value} ->
          {:miss, put(key, value)}

        # Fallback failed
        other ->
          {:miss, :error, other}
      end
    else
      :miss
    end
  end
end
