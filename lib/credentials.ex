defmodule AwsSigner.Credentials do
  defstruct access_key_id: nil,
            expiration: nil,
            secret_access_key: nil,
            token: nil
end
