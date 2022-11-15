defmodule AwsSigner.Logger do
  @behaviour Tesla.Middleware

  def call(req_env, next, opts) do
    if opts[:log] do
      Tesla.Middleware.Logger.call(req_env, next, opts)
    else
      Tesla.run(req_env, next)
    end
  end
end
