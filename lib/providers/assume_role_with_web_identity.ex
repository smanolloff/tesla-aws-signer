defmodule AwsSigner.Providers.AssumeRoleWithWebIdentity do
  alias AwsSigner.Credentials

  @client Application.get_env(:aws_signer, :aws_client, AwsSigner.Client)

  @spec get_credentials(
          arn: String.t(),
          region: String.t(),
          session_name: String.t(),
          web_identity_token: String.t()
        ) :: %Credentials{}

  def get_credentials(opts) do
    arn = Keyword.fetch!(opts, :arn)
    region = Keyword.fetch!(opts, :region)
    session_name = Keyword.get(opts, :session_name, "default")
    token = Keyword.fetch!(opts, :web_identity_token)

    %{status: 200, body: body} =
      @client.get!("https://sts.#{region}.amazonaws.com?#{query(arn, session_name, token)}")

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
