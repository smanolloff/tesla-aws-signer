# Tesla AWS Signer

A [Tesla](https://github.com/teamon/tesla) plug for signing HTTP requests with [AWS Signature Version 4](https://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html).

## Installation

```
def deps do
  [
    {:aws_signer, "~> 1.0"}
  ]
end
```

## Usage

```elixir
defmodule MyHttpClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://my-aws-elasticsearch.eu-central-1.es.amazonaws.com"
  plug Tesla.Middleware.JSON
  plug AwsSigner.TeslaMiddleware, options

  adapter Tesla.Adapter.Hackney, path_encode_fun: &AwsSigner.Util.encode_rfc3986/1
end
```

where `options` is a keyword list:

```elixir
[
  auth_method: :assume_role     # (required) see below for possible values
  region: "eu-central-1",       # (required)
  service: "es",                # (required)
  arn: "arn:aws:iam::123..."    # (required)
  cachex_name: :aws_cache       # (optional) cache name (requires cachex); default: nil
  session_name: "..."           # (optional) aws session name
  access_key_id: "...",         # required if auth_method is :assume_role
  secret_access_key: "...",     # required if auth_method is :assume_role
  web_identity_token: "..."     # required if auth_method is :assume_role_with_web_identity
]

```

`auth_method` can be one of:
* `:instance_profile`
* `:assume_role`
* `:assume_role_with_web_identity`

You can read more about [AWS STS](https://docs.aws.amazon.com/STS/latest/APIReference/API_Operations.html) and [AWS Instance Profiles](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) in the AWS official docs.

## Logging

For debugging purposes, you can enable logging all requests to AWS STS service (made when issuing tokens). Do so with caution, AWS keys are not something you want in your logs (you know, security).

In you app's config:

```elixir
config :aws_signer, logging: true
```

## Caching

When caching is disabled (the default), a new AWS key will be issued for signing each request.

When caching is enabled, AWS keys will be re-used on subsequent requests.

To enable caching, you must:
1. [Start Cachex](https://hexdocs.pm/cachex/getting-started.html) with a specific `name`
2. Configure `cachex_name` option with the same value used for `name` in step 1.

## Caveats

#### HTTP adapter

Make sure your HTTP adapter's path encoding follows the RFC3986 standard as expected by AWS. If you use [`hackney`](https://github.com/benoitc/hackney), you must instruct it to use an external function for that purpose (as shown above in the Usage example):

```elixir
  adapter Tesla.Adapter.Hackney, path_encode_fun: &AwsSigner.Util.encode_rfc3986/1
```

#### Supported auth methods

This library provides basic support for AWS [`AssumeRole`](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html), [`AssumeRoleWithWebIdentity`](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html) and [`InstanceProfile`](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) credential providers. More providers should be straightforward to add, pull requests are welcome.

#### Supported AWS services

This has been tested with `es` service only (the AWS keyword for Elasticsearch service).

It *should* work for other AWS services, but there may be exceptions -- like the `s3` service, which [according to the AWS docs](https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html) expects double-encoded path segments. Support for this should be easy to add, pull requests are welcome.

Also, keep in mind I have not personally tested the `assume_role_with_web_identity` auth method in production yet, I'd appreciate any feedback.

## Contributing

Everyone is welcome to contribute. When submitting a Pull Request, please make sure to:

1. Put a clear, concise reasoning for your change in the PR
1. Use `mix format` for code formatting
1. Cover new/changed functionality with tests
1. Ensure all tests pass
