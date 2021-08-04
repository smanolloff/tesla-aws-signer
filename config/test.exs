use Mix.Config

config :aws_signer,
  cache_provider: Mocks.Cache,
  datetime_provider: Mocks.DateTime,
  aws_client: Mocks.AwsClient,
  logger_middleware: Tesla.Middleware.Logger

config :tesla,
  adapter: Tesla.Mock
