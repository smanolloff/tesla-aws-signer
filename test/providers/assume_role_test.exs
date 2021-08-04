defmodule AwsSigner.Providers.AssumeRoleTest do
  use ExUnit.Case
  alias AwsSigner.Providers.AssumeRole

  test "get_credentials/1" do
    resp_body = """
    <AssumeRoleResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
      <AssumeRoleResult>
        <AssumedRoleUser>
          <AssumedRoleId>roleid:aws-test-role</AssumedRoleId>
          <Arn>arn:aws:sts::123456789012:assumed-role/aws-test-role</Arn>
        </AssumedRoleUser>
        <Credentials>
          <AccessKeyId>assumed_accesskey</AccessKeyId>
          <SecretAccessKey>assumed_secretkey</SecretAccessKey>
          <SessionToken>assumed_sessiontoken</SessionToken>
          <Expiration>2020-01-01T00:00:00Z</Expiration>
        </Credentials>
      </AssumeRoleResult>
      <ResponseMetadata>
        <RequestId>e9cd9ed0-8ce8-4819-a1bf-ead6f886533a</RequestId>
      </ResponseMetadata>
    </AssumeRoleResponse>
    """

    datetime = ~U[2020-01-01T01:00:00Z]

    opts = [
      arn: "arn:aws:iam::123456789012:role/aws-test-role",
      region: "eu-central-1",
      access_key_id: "_TEST_ACCESS_KEY_ID_",
      secret_access_key: "_TEST_SECRET_ACCESS_KEY_"
    ]

    {call_args, result} =
      Mocks.DateTime.with_time(datetime, fn ->
        Mocks.AwsClient.with_response(%{status: 200, body: resp_body}, fn ->
          AssumeRole.get_credentials(opts)
        end)
      end)

    signer_opts = [
      verb: "POST",
      url: "https://sts.eu-central-1.amazonaws.com",
      content:
        "Action=AssumeRole&RoleArn=arn%3Aaws%3Aiam%3A%3A123456789012%3Arole%2Faws-test-role&RoleSessionName=default&Version=2011-06-15",
      region: "eu-central-1",
      service: "sts",
      access_key_id: "_TEST_ACCESS_KEY_ID_",
      secret_access_key: "_TEST_SECRET_ACCESS_KEY_",
      type: "AWS-HMAC"
    ]

    [req_url, req_body, [headers: req_headers]] = call_args

    assert req_url == signer_opts[:url]
    assert req_body == signer_opts[:content]

    assert result == %AwsSigner.Credentials{
             access_key_id: "assumed_accesskey",
             expiration: "2020-01-01T00:00:00Z",
             secret_access_key: "assumed_secretkey",
             token: "assumed_sessiontoken"
           }

    signature =
      Mocks.DateTime.with_time(datetime, fn ->
        AwsSigner.sign_v4(signer_opts)
      end)

    assert req_headers ==
             [{"content-type", "application/x-www-form-urlencoded"} | signature]
  end
end
