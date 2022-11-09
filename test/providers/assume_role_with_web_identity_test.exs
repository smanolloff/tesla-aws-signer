defmodule AwsSigner.Providers.AssumeRoleWithWebIdentityTest do
  use ExUnit.Case
  alias AwsSigner.Providers.AssumeRoleWithWebIdentity

  test "get_credentials/1" do
    resp_body = """
    <AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
      <AssumeRoleWithWebIdentityResult>
        <Audience>sts.amazonaws.com</Audience>
        <AssumedRoleUser>
          <AssumedRoleId>AROA4Q7OQAZYHVKH4GGNZ:simo</AssumedRoleId>
          <Arn>arn:aws:sts::861104244336:assumed-role/transactions-esjobs-aws-stage-service-account/simo</Arn>
        </AssumedRoleUser>
        <Provider>arn:aws:iam::861104244336:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/26A73B686B58B9B212C813AC28C1DF68</Provider>
        <Credentials>
          <AccessKeyId>assumed_webaccesskey</AccessKeyId>
          <SecretAccessKey>assumed_websecretkey</SecretAccessKey>
          <SessionToken>assumed_websessiontoken</SessionToken>
          <Expiration>2021-01-01T00:00:00Z</Expiration>
        </Credentials>
        <SubjectFromWebIdentityToken>irrelevant-value-here</SubjectFromWebIdentityToken>
      </AssumeRoleWithWebIdentityResult>
      <ResponseMetadata>
        <RequestId>204cb736-e2bb-48bb-b924-21f74e9f292a</RequestId>
      </ResponseMetadata>
    </AssumeRoleWithWebIdentityResponse>
    """

    datetime = ~U[2020-01-01T01:00:00Z]

    opts = [
      arn: "arn:aws:iam::123456789012:role/aws-test-web-role",
      region: "eu-central-1",
      web_identity_token: "_TEST_WEB_IDENTITY_TOKEN_"
    ]

    {call_args, result} =
      Mocks.DateTime.with_time(datetime, fn ->
        Mocks.AwsClient.with_response(%{status: 200, body: resp_body}, fn ->
          AssumeRoleWithWebIdentity.get_credentials(opts)
        end)
      end)

    assert [url] = call_args

    assert url ==
             "https://sts.eu-central-1.amazonaws.com?Action=AssumeRoleWithWebIdentity" <>
               "&RoleArn=arn%3Aaws%3Aiam%3A%3A123456789012%3Arole%2Faws-test-web-role" <>
               "&RoleSessionName=default" <>
               "&Version=2011-06-15" <>
               "&WebIdentityToken=_TEST_WEB_IDENTITY_TOKEN_"

    assert result == %AwsSigner.Credentials{
             access_key_id: "assumed_webaccesskey",
             expiration: "2021-01-01T00:00:00Z",
             secret_access_key: "assumed_websecretkey",
             token: "assumed_websessiontoken"
           }
  end
end
