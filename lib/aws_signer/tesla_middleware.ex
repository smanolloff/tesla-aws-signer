defmodule AwsSigner.TeslaMiddleware do
  alias AwsSigner
  require Logger

  @behaviour Tesla.Middleware
  @cache_provider Application.get_env(:aws_signer, :cache_provider, Cachex)

  def call(env, next, opts) do
    env
    |> sign(opts)
    |> Tesla.run(next)
  end

  def sign(env, opts) do
    credentials = get_cedentials(opts)

    signature =
      AwsSigner.sign_v4(
        verb: env.method |> to_string() |> String.upcase(),
        url: Tesla.build_url(env.url, env.query),
        content: env.body || "",
        region: Keyword.fetch!(opts, :region),
        service: Keyword.fetch!(opts, :service),
        access_key_id: credentials.access_key_id,
        secret_access_key: credentials.secret_access_key,
        session_token: credentials.token,
        type: "AWS-HMAC"
      )

    %{env | headers: merge_headers(signature, env.headers)}
  end

  #
  # private
  #

  defp provider(opts) do
    case Keyword.fetch!(opts, :auth_method) do
      :instance_profile -> AwsSigner.Providers.InstanceProfile
      :assume_role -> AwsSigner.Providers.AssumeRole
      :assume_role_with_web_identity -> AwsSigner.Providers.AssumeRoleWithWebIdentity
    end
  end

  #
  # Checks cache for already available credentials for this arn
  # If not, calls provider.get_credentials()
  #
  if Code.ensure_compiled(@cache_provider) == {:module, @cache_provider} do
    defp get_cedentials(opts) do
      arn = Keyword.fetch!(opts, :arn)
      cache = Keyword.get(opts, :cachex_name)
      fallback = fallback_fn(opts)

      if cache do
        case @cache_provider.fetch(cache, arn, fallback) do
          {:commit, res} ->
            {:ok, expiration, _} = DateTime.from_iso8601(res.expiration)
            epoch_ms = DateTime.to_unix(expiration, :millisecond)

            @cache_provider.expire_at(cache, arn, epoch_ms - 10_000)
            res

          {op, res} when op in [:ok, :ignore] ->
            res

          err ->
            Logger.error("Cache error: #{inspect(err)}")
            fallback.()
        end
      else
        fallback.()
      end
    end
  else
    defp get_cedentials(opts) do
      apply(provider(opts), :get_credentials, [opts])
    end
  end

  defp fallback_fn(opts) do
    metadata = Logger.metadata()

    fn ->
      # Don't lose logger metadata
      Logger.metadata(metadata)
      apply(provider(opts), :get_credentials, [opts])
    end
  end

  defp merge_headers(new_headers, env_headers) do
    new_names = for {k, _} <- new_headers, do: k

    headers =
      Enum.filter(env_headers, fn {name, _} ->
        String.downcase(name) not in new_names
      end)

    headers ++ new_headers
  end
end
