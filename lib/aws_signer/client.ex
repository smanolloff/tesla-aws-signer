defmodule AwsSigner.Client do
  use Tesla

  plug AwsSigner.Logger
end
