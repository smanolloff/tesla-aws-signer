defmodule AwsSigner.TeslaMiddleware do
  @behaviour Tesla.Middleware

  def call(env, next, opts) do
    env
    |> sign(opts)
    |> Tesla.run(next)
  end

  def sign(env, opts) do
    credentials = get_credentials(opts)

    signature =
      AwsSigner.sign_v4(
        log: opts[:log],
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

  defp get_credentials(opts) do
    if opts[:cache],
      do: get_credentials_from_cache(opts),
    else: get_credentials_from_provider(opts)
  end

  defp get_credentials_from_cache(opts) do
    arn = Keyword.fetch!(opts, :arn)
    fallback_fn = fn ->
      case get_credentials_from_provider(opts) do
        %AwsSigner.Credentials{} = res ->
          {:ok, expiration, _} = DateTime.from_iso8601(res.expiration)
          expire_at = DateTime.to_unix(expiration, :millisecond) - 10_000
          {:ok, res, expire_at}

        any ->
          {:error, any}
      end
    end

    case AwsSigner.Cache.fetch(arn, fallback_fn) do
      {:hit, {value, _}} -> value
      {:miss, {value, _}} -> value
      {:miss, :error, any} -> raise "Bad return from cache fallback: #{inspect(any)}"
    end
  end

  defp get_credentials_from_provider(opts) do
    provider(opts).get_credentials(opts)
  end

  defp provider(opts) do
    case Keyword.fetch!(opts, :auth_method) do
      :instance_profile -> AwsSigner.Providers.InstanceProfile
      :assume_role -> AwsSigner.Providers.AssumeRole
      :assume_role_with_web_identity -> AwsSigner.Providers.AssumeRoleWithWebIdentity
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
