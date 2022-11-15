defmodule AwsSigner.Cache do
  require Logger
  use Agent

  def start_link(opts \\ []),
    do: Agent.start_link(fn -> {opts[:log], %{}} end, name: __MODULE__)

  def fetch(key, fallback \\ nil) do
    case Agent.get(__MODULE__, & &1) do
      {log, %{^key => {value, nil}}} ->
        hit(key, value, nil, log)

      {log, %{^key => {value, t}}} ->
        now = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        if now > t,
          do: miss(key, fallback, log),
        else: hit(key, value, t, log)

      {log, %{}} ->
        miss(key, fallback, log)
    end
  end

  def put(key, value, expire_at \\ nil) do
    Agent.update(__MODULE__, fn {log, store} ->
      {log, Map.put(store, key, {value, expire_at})}
    end)

    {value, expire_at}
  end

  def delete(key) do
    Agent.update(__MODULE__, fn {log, store} ->
      {log, Map.delete(store, key)}
    end)
  end

  #
  # private
  #

  defp hit(key, value, expire_at, log) do
    if log,
      do: Logger.info("Cache hit: #{inspect(key)} (#{expire_at})")

    {:hit, {value, expire_at}}
  end

  defp miss(key, fallback, log) do
    if log,
      do: Logger.info("Cache miss: #{inspect(key)}")

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
