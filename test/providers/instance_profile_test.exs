defmodule AwsSigner.Providers.InstanceProfileTest do
  use ExUnit.Case
  alias AwsSigner.Providers.InstanceProfile

  test "get_credentials/0" do
    resp_body = """
    {
      "AccessKeyId": "accesskey",
      "Code": "Success",
      "Expiration": "2020-01-01T00:00:00Z",
      "LastUpdated": "2000-01-01T00:00:00Z",
      "SecretAccessKey": "secretkey",
      "Token": "sessiontoken",
      "Type": "AWS-HMAC"
    }
    """

    opts = [arn: "arn:aws:iam::123456789012:role/aws-test-role"]

    {call_args, result} =
      Mocks.AwsClient.with_response(%{status: 200, body: resp_body}, fn ->
        InstanceProfile.get_credentials(opts)
      end)

    assert call_args == [
             "http://169.254.169.254/latest/meta-data/iam/security-credentials/aws-test-role"
           ]

    assert result == %AwsSigner.Credentials{
             access_key_id: "accesskey",
             expiration: "2020-01-01T00:00:00Z",
             secret_access_key: "secretkey",
             token: "sessiontoken"
           }
  end
end
