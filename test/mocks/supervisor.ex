defmodule Mocks.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @impl true
  def init(_) do
    children = [
      Mocks.AwsClient,
      Mocks.Cache,
      Mocks.DateTime
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
