defmodule AwsSigner.Logger do
  @behaviour Tesla.Middleware

  def call(req_env, next, opts) do
    if Application.get_env(:aws_signer, :logging, false) do
      Tesla.Middleware.Logger.call(req_env, next, opts)
    else
      Tesla.run(req_env, next)
    end
  end
end
