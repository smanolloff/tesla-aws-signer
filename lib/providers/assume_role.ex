defmodule AwsSigner.Providers.AssumeRole do
  alias AwsSigner.Credentials

  @client Application.get_env(:aws_signer, :aws_client, AwsSigner.Client)

  @spec get_credentials(
          arn: String.t(),
          region: String.t(),
          session_name: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t()
        ) :: %Credentials{}

  def get_credentials(opts) do
    arn = Keyword.fetch!(opts, :arn)
    region = Keyword.fetch!(opts, :region)
    access_key_id = Keyword.fetch!(opts, :access_key_id)
    secret_access_key = Keyword.fetch!(opts, :secret_access_key)
    session_name = Keyword.get(opts, :session_name, "default")

    url = "https://sts.#{region}.amazonaws.com"
    req_body = content(arn, session_name)

    signature =
      AwsSigner.sign_v4(
        verb: "POST",
        url: url,
        content: req_body,
        region: region,
        service: "sts",
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        type: "AWS-HMAC"
      )

    content_type = "application/x-www-form-urlencoded"
    req_headers = [{"content-type", content_type} | signature]

    %{status: 200, body: resp_body} = @client.post!(url, req_body, headers: req_headers)

    %AwsSigner.Credentials{
      access_key_id: extract(resp_body, "AccessKeyId"),
      expiration: extract(resp_body, "Expiration"),
      secret_access_key: extract(resp_body, "SecretAccessKey"),
      token: extract(resp_body, "SessionToken")
    }
  end

  #
  # private
  #

  defp encode(str),
    do: URI.encode_www_form(str)

  defp content(arn, session_name) do
    "Action=AssumeRole" <>
      "&RoleArn=#{encode(arn)}" <>
      "&RoleSessionName=#{encode(session_name)}" <>
      "&Version=2011-06-15"
  end

  defp extract(xml, key) do
    ekey = Regex.escape(key)

    ~r{<#{ekey}>(.*)(?=</#{ekey}>)}s
    |> Regex.run(xml, capture: [1])
    |> hd()
  end
end
