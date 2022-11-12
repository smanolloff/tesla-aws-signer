defmodule AwsSigner.Providers.AssumeRoleWithWebIdentity do
  alias AwsSigner.Credentials
  alias AwsSigner.Cache
  require Logger

  @client Application.get_env(:aws_signer, :aws_client, AwsSigner.Client)

  @spec get_credentials(
          arn: String.t(),
          region: String.t(),
          session_name: String.t(),
          web_identity_token_file: String.t()
        ) :: %Credentials{}

  def get_credentials(opts) do
    arn = Keyword.fetch!(opts, :arn)
    region = Keyword.fetch!(opts, :region)
    session_name = Keyword.get(opts, :session_name, "default")
    token = get_token(opts)

    body =
      case @client.get!("https://sts.#{region}.amazonaws.com?#{query(arn, session_name, token)}") do
        %{status: 200, body: body} ->
          body

        # If it fails with 400, most likely the token has expired
        %{status: 400} ->
          Logger.info("Re-reading web identity token")
          Process.sleep(10000)
          token = get_token(opts, true)

          # If it fails again, let it crash
          %{status: 200, body: body} =
            @client.get!("https://sts.#{region}.amazonaws.com?#{query(arn, session_name, token)}")

          body
      end

    %Credentials{
      access_key_id: extract(body, "AccessKeyId"),
      expiration: extract(body, "Expiration"),
      secret_access_key: extract(body, "SecretAccessKey"),
      token: extract(body, "SessionToken")
    }
  end

  #
  # private
  #

  defp get_token(opts, force \\ false) do
    filename = Keyword.fetch!(opts, :web_identity_token_file)
    fallback_fn = fn ->
      token = File.read!(filename) |> String.trim()
      Logger.error("READING FILE: #{token}")
      {:ok, token, :timer.seconds(3600)}
    end

    if force, do: Cache.delete(filename)

    case Cache.fetch(filename, fallback_fn) do
      {:hit, {value, _}} -> value
      {:miss, {value, _}} -> value
      {:miss, :error, any} -> raise "Bad return from cache fallback: #{inspect(any)}"
    end
  end

  defp encode(str),
    do: URI.encode_www_form(str)

  defp query(arn, session_name, token) do
    "Action=AssumeRoleWithWebIdentity" <>
      "&RoleArn=#{encode(arn)}" <>
      "&RoleSessionName=#{encode(session_name)}" <>
      "&Version=2011-06-15" <>
      "&WebIdentityToken=#{encode(token)}"
  end

  defp extract(xml, key) do
    ekey = Regex.escape(key)

    ~r{<#{ekey}>(.*)(?=</#{ekey}>)}s
    |> Regex.run(xml, capture: [1])
    |> hd()
  end
end
