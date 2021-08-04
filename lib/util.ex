defmodule AwsSigner.Util do
  #
  # :hackney_url.pathencode/1 does not work for us, because:
  #   - it can't double-encode
  #   - it encodes "+" as "%20" (instead of "%2B")
  #   - it encodes " " as "+"   (instead of "%20")
  #
  # URI.encode_www_form/0 is fine, except:
  #   - it encodes " " as "+"   (instead of "%20")
  #
  # Double-encoding and using "%20" instead of "+"
  # are required when building the AWS canonical path
  #

  def encode_rfc3986(nil),
    do: nil

  def encode_rfc3986(str) do
    String.replace(str, ~r{[^/]+}, fn part ->
      part
      |> URI.encode_www_form()
      |> String.replace("+", "%20")
    end)
  end
end
