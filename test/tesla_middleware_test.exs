defmodule AwsSigner.TeslaMiddlewareTest do
  use ExUnit.Case
  alias AwsSigner.TeslaMiddleware
  require Assertions
  import Assertions

  setup do
    AwsSigner.Cache.start_link()
    :ok
  end

  def assume_role_response do
    """
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
          <Expiration>2020-01-01T12:00:00Z</Expiration>
        </Credentials>
      </AssumeRoleResult>
      <ResponseMetadata>
        <RequestId>e9cd9ed0-8ce8-4819-a1bf-ead6f886533a</RequestId>
      </ResponseMetadata>
    </AssumeRoleResponse>
    """
  end

  def assume_role_with_web_identity_response do
    """
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
  end

  def instance_profile_response do
    """
    {
      "AccessKeyId": "instance_accesskey",
      "Code": "Success",
      "Expiration": "2020-01-01T12:00:00Z",
      "LastUpdated": "2000-01-01T00:00:00Z",
      "SecretAccessKey": "instance_secretkey",
      "Token": "instance_token",
      "Type": "AWS-HMAC"
    }
    """
  end

  def common_aws_opts do
    [
      cache: true,
      arn: "arn:aws:iam::123456789012:role/aws-test-role",
      region: "eu-central-1",
      service: "es"
    ]
  end

  test "sign/2 for assume_role" do
    aws_opts =
      Keyword.merge(common_aws_opts(),
        auth_method: :assume_role,
        access_key_id: "_TEST_ACCESS_KEY_ID_",
        secret_access_key: "_TEST_SECRET_ACCESS_KEY_"
      )

    env = %Tesla.Env{url: "http://foo.bar/baba"}

    {_, %{headers: headers}} =
      Mocks.DateTime.with_time(~U[2020-01-01T00:00:00Z], fn ->
        Mocks.AwsClient.with_response(%{status: 200, body: assume_role_response()}, fn ->
          TeslaMiddleware.sign(env, aws_opts)
        end)
      end)

    # Exact signature does not need to be asserted here
    # (this is part of the signer_test)
    # Instead, we only want to ensure that the plug uses
    # the credentials from the assume role response
    header_map = Map.new(headers)
    assert header_map["host"] == "foo.bar"
    assert header_map["x-amz-date"] == "20200101T000000Z"

    assert header_map["authorization"] =~
             ~r{Credential=assumed_accesskey/20200101/eu-central-1/es/aws4_request}
  end

  test "sign/2 for assume_role_with_web_identity" do
    aws_opts =
      Keyword.merge(common_aws_opts(),
        auth_method: :assume_role_with_web_identity,
        web_identity_token_file: Path.join([File.cwd!, "test", "mocks", "token"])
      )

    env = %Tesla.Env{url: "http://foo.bar/baba"}

    {_, %{headers: headers}} =
      Mocks.DateTime.with_time(~U[2020-01-01T00:00:00Z], fn ->
        Mocks.AwsClient.with_response(
          %{status: 200, body: assume_role_with_web_identity_response()},
          fn ->
            TeslaMiddleware.sign(env, aws_opts)
          end
        )
      end)

    # Exact signature does not need to be asserted here
    # (this is part of the signer_test)
    # Instead, we only want to ensure that the plug uses
    # the credentials from the assume role response
    header_map = Map.new(headers)
    assert header_map["host"] == "foo.bar"
    assert header_map["x-amz-date"] == "20200101T000000Z"

    assert header_map["authorization"] =~
             ~r{Credential=assumed_webaccesskey/20200101/eu-central-1/es/aws4_request}
  end

  test "sign/2 for instance_profile" do
    aws_opts =
      Keyword.merge(common_aws_opts(),
        auth_method: :instance_profile
      )

    env = %Tesla.Env{url: "http://foo.bar/baba"}

    {_, %{headers: headers}} =
      Mocks.DateTime.with_time(~U[2020-01-01T00:00:00Z], fn ->
        Mocks.AwsClient.with_response(%{status: 200, body: instance_profile_response()}, fn ->
          TeslaMiddleware.sign(env, aws_opts)
        end)
      end)

    # Exact signature does not need to be asserted here
    # (this is part of the signer_test)
    # Instead, we only want to ensure that the plug uses
    # the credentials from the instance profile response
    header_map = Map.new(headers)
    assert header_map["host"] == "foo.bar"
    assert header_map["x-amz-date"] == "20200101T000000Z"
    assert header_map["x-amz-security-token"] == "instance_token"

    assert header_map["authorization"] =~
             ~r{Credential=instance_accesskey/20200101/eu-central-1/es/aws4_request}
  end

  test "sign/2 header overwriting" do
    aws_opts = Keyword.merge(common_aws_opts(), auth_method: :instance_profile)

    env = %Tesla.Env{
      url: "http://foo.bar/baba",
      headers: [{"host", "http://bar.baz"}, {"baba", "pena"}]
    }

    {_, %{headers: headers}} =
      Mocks.DateTime.with_time(~U[2020-01-01T00:00:00Z], fn ->
        Mocks.AwsClient.with_response(%{status: 200, body: instance_profile_response()}, fn ->
          TeslaMiddleware.sign(env, aws_opts)
        end)
      end)

    # 1. Ensure headers are not duplicated
    header_names = for {k, _} <- headers, do: k

    assert_lists_equal(header_names, [
      "authorization",
      "host",
      "x-amz-content-sha256",
      "x-amz-date",
      "x-amz-security-token",
      "baba"
    ])

    # 2. Ensure headers are overwritten
    header_map = Map.new(headers)
    assert header_map["host"] == "foo.bar"
    assert header_map["x-amz-date"] == "20200101T000000Z"
    assert header_map["x-amz-security-token"] == "instance_token"
    assert header_map["baba"] == "pena"
  end

  test "sign/2: cache hit" do
    # Not yet expired
    cached_response = %AwsSigner.Credentials{
      expiration: "2020-01-01T12:00:00Z",
      access_key_id: "cached_accesskey",
      secret_access_key: "cached_secretkey",
      token: "cached_token"
    }

    aws_opts =
      Keyword.merge(common_aws_opts(), auth_method: :instance_profile)

    env = %Tesla.Env{url: "http://foo.bar/baba"}
    AwsSigner.Cache.put(aws_opts[:arn], cached_response)

    sign_resp =
      Mocks.DateTime.with_time(~U[2020-01-01T00:00:00Z], fn ->
        {call_args, sign_resp} =
          Mocks.AwsClient.with_response(:should_not_be_called, fn ->
            TeslaMiddleware.sign(env, aws_opts)
          end)

        # Plug.sign should not call AwsClient.sign at all (cached)
        assert call_args == :unset
        sign_resp
      end)

    header_map = Map.new(sign_resp.headers)
    assert header_map["x-amz-security-token"] == "cached_token"
    assert header_map["authorization"] =~ ~r{Credential=cached_accesskey}
  end
end
