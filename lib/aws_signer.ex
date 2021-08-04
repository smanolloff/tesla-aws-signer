defmodule AwsSigner do
  require Logger

  @datetime_provider Application.get_env(:aws_signer, :datetime_provider, DateTime)

  #
  # NOTE: if service is "s3", this signature wont work
  #

  def sign_v4(opts) do
    # "GET"
    verb = Keyword.fetch!(opts, :verb)

    # "https://myurl.com/a?b=c"
    url = Keyword.fetch!(opts, :url)

    # ""
    content = Keyword.fetch!(opts, :content)

    # "eu-central-1"
    region = Keyword.fetch!(opts, :region)

    # "es"
    service = Keyword.fetch!(opts, :service)

    # "ASIARTL3K..."
    access_key_id = Keyword.fetch!(opts, :access_key_id)

    # "zOpPHbaD4..."
    secret_access_key = Keyword.fetch!(opts, :secret_access_key)

    # "FwoGZXIvYXdzEPT///...""
    session_token = Keyword.get(opts, :session_token)

    # Prevent unsupported formats
    "AWS-HMAC" = Keyword.fetch!(opts, :type)

    content_sha = hash(content)
    uri = URI.parse(url)
    date = amz_date()

    # host and all amz-* headers are required
    # The order of this list is important
    headers = [
      {"host", uri.host},
      {"x-amz-content-sha256", content_sha},
      {"x-amz-date", date}
    ]

    headers =
      if session_token,
        do: headers ++ [{"x-amz-security-token", session_token}],
        else: headers

    creq = canonical_request(verb, uri, headers, content_sha)
    sts = string_to_sign(date, creq, region, service)
    sig = signature(secret_access_key, date, region, service, sts)

    auth =
      "AWS4-HMAC-SHA256 Credential=#{access_key_id}/#{scope(date, region, service)}, " <>
        "SignedHeaders=#{Enum.map_join(headers, ";", fn {k, _} -> k end)}, " <>
        "Signature=#{sig}"

    [{"authorization", auth} | headers]
  end

  #
  # private
  #

  def hash(string),
    do: :crypto.hash(:sha256, string) |> Base.encode16(case: :lower)

  def hmac(key, string),
    do: :crypto.hmac(:sha256, key, string)

  #
  # "2020-11-19 12:28:01.699631Z" => "20201119T122801Z"
  #
  def amz_date() do
    @datetime_provider.utc_now()
    |> Map.put(:microsecond, {0, 0})
    |> DateTime.to_iso8601()
    |> String.replace(~r/[:-]/, "")
  end

  # https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
  def canonical_request(verb, uri, headers, content_sha) do
    [
      verb,
      path(uri.path),
      normalize_query(uri.query),
      canonical_headers(headers),
      signed_headers(headers),
      content_sha
    ]
    |> Enum.join("\n")
  end

  def path(nil),
    do: "/"

  #
  # Canonical path is an encoded version of the encoded path
  # so we need to double-encode it here
  #
  # Example:
  #   get("/documents and settings/")
  #
  #   will be converted by the adapter (later):
  #     /documents%20and%20settings/
  #
  #   but the canonical form (which we need here) is:
  #     /documents%2520and%2520settings/
  #
  def path(str) do
    str
    |> AwsSigner.Util.encode_rfc3986()
    |> AwsSigner.Util.encode_rfc3986()
  end

  #
  # Sort query params by name first, then by value (if present). Append "=" to
  # params with missing value.
  # Example: "foo=bar&baz" becomes "baz=&foo=bar"
  #
  def normalize_query(nil),
    do: ""

  def normalize_query(""),
    do: ""

  def normalize_query(query) do
    query
    |> String.split("&")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.sort()
    |> Enum.map_join("&", fn
      [key, value] -> key <> "=" <> value
      [key] -> key <> "="
    end)
  end

  def canonical_headers(headers),
    do: Enum.map_join(headers, "", fn {k, v} -> "#{k}:#{v}\n" end)

  def signed_headers(headers),
    do: Enum.map_join(headers, ";", fn {k, _} -> k end)

  def string_to_sign(date, creq, region, service) do
    [
      "AWS4-HMAC-SHA256",
      date,
      scope(date, region, service),
      hash(creq)
    ]
    |> Enum.join("\n")
  end

  def scope(date, region, service),
    do: [String.slice(date, 0..7), region, service, "aws4_request"] |> Enum.join("/")

  def signature(secret_access_key, date, region, service, sts) do
    "AWS4#{secret_access_key}"
    |> hmac(String.slice(date, 0..7))
    |> hmac(region)
    |> hmac(service)
    |> hmac("aws4_request")
    |> hmac(sts)
    |> Base.encode16(case: :lower)
  end
end
