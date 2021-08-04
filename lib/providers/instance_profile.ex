defmodule AwsSigner.Providers.InstanceProfile do
  alias AwsSigner.Credentials

  @client Application.get_env(:aws_signer, :aws_client, AwsSigner.Client)

  @spec get_credentials(arn: String.t()) :: %Credentials{}

  def get_credentials(opts) do
    arn = Keyword.fetch!(opts, :arn)
    [_, role] = String.split(arn, "role/")

    %{status: 200, body: body} =
      @client.get!("http://169.254.169.254/latest/meta-data/iam/security-credentials/#{role}")

    decoded = Jason.decode!(body)

    %Credentials{
      access_key_id: decoded["AccessKeyId"],
      expiration: decoded["Expiration"],
      secret_access_key: decoded["SecretAccessKey"],
      token: decoded["Token"]
    }
  end
end
