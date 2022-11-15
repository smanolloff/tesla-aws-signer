defmodule AwsSigner.Providers.AssumeRoleWithWebIdentity do
  alias AwsSigner.Credentials

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
    url = "https://sts.#{region}.amazonaws.com?#{query(arn, session_name,  token)}"

    %{status: 200, body: body} = @client.get!(url)

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

  # No need for cache here
  # The web identity token file is read very rarely
  # (only when the session token expires, eg. hourly)
  defp get_token(opts) do
    Keyword.fetch!(opts, :web_identity_token_file)
    |> File.read!()
    |> String.trim()
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
