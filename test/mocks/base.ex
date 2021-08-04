defmodule Mocks.Base do
  @moduledoc """
  http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/
  """
  defmacro __using__(opts) do
    quote location: :keep do
      @initial_state unquote(Keyword.fetch!(opts, :state))

      use GenServer

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: __MODULE__)
      end

      @impl true
      def init(_) do
        {:ok, @initial_state}
      end

      def call(arg), do: GenServer.call(__MODULE__, arg, :infinity)

      def get_state, do: call({:get_state, []})
      def get_state(arg), do: call({:get_state, [arg]})

      def set_state(arg), do: call({:set_state, [arg]})

      @impl true
      def handle_call({:get_state, args}, _from, state),
        do: {:reply, apply(__MODULE__, :_get_state, [state | args]), state}

      def handle_call({:set_state, args}, _from, state),
        do: {:reply, :ok, apply(__MODULE__, :_set_state, [state | args])}
    end
  end
end
