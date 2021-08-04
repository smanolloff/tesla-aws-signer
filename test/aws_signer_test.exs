defmodule AwsSignerTest do
  use ExUnit.Case
  require Assertions
  import Assertions

  #
  # Signing an elasticsearch request
  #
  test "sign_v4/1" do
    opts = [
      verb: "GET",
      url:
        "https://vpc-payout-history-theta-u6tts4mz6gfvzywhk2xvaq2qfa.eu-central-1.es.amazonaws.com/_cat/indices",
      content: "",
      region: "eu-central-1",
      service: "es",
      access_key_id: "ASIAWKJF5BC23DUIINXY",
      secret_access_key: "9oU0vUe5xldKjuyTSDStcdNOPVD29W2qJCsdutun",
      type: "AWS-HMAC",
      session_token:
        "IQoJb3JpZ2luX2VjEOj//////////wEaDGV1LWNlbnRyYWwtMSJHMEUCICrYM2rWPdToIVoHCFAEG1yf2SEah1gDKuZp" <>
          "+QAbWgZZAiEA7xBZ8N/goSft30Pv3DCw+MGNQsEY4YjamzYfKMq3zRsqkQIIYRACGgw0MzQ0MDgwNjUyMDUiDE5J5ccxEH9u+FwldCruA" <>
          "VZ6Gx2O13B+JZpExaUFd8Qy0oQJvlQkMMks9DSd2FN1SNsjCcL6cmh9kSf431ED/tPNtlPeuvx6Jdqg3NM6FswRrqc4YMsja/D0Igw+r3" <>
          "JRrrgX0qjEQZMHr25w2ucswmDuDbiQ9bji5ssM/Hpl0P9fm39rqa0cdnf2/Tuqm8NhrQ/rDL/YlwiftZhKeaQjvb5EwqRQCM1YOsYTWrG" <>
          "oACZj6wcRNhlbNLaWtpx6gRN3oRx2deIXoW1rbuVdhRsyI0krCjPGYI7qGZy0SuFI5NdBqz7yhoKJbN2c/Ek0tdnkBaJMMBufLVji0476" <>
          "PeEw+qfa/QU6nQE6DctTL0rlAD6kknzpwOSS99Hmq5k+tnDhF4uTvACpNbbZD8effnu9LT+UxdsuCDG469Os6SVnkkqd0OrlRme2jp+Wc" <>
          "YsdtabKZMm68dYfzWb5h5BGCJ0W1poMKP3fKByJdBpdmnX62xgylfDNV0lsNMsfXLzcBiVzzsb4jLBw96VvY4Re4vryAdCTCSQt/3RBwt" <>
          "qLD+JuEc6NBIgw"
    ]

    signature =
      Mocks.DateTime.with_time(~U[2020-11-19T15:51:50Z], fn -> AwsSigner.sign_v4(opts) end)

    assert signature == [
             {"authorization",
              "AWS4-HMAC-SHA256 Credential=ASIAWKJF5BC23DUIINXY/20201119/eu-central-1/es/aws4_request, " <>
                "SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token, " <>
                "Signature=0d6ec3cf0fc0e9fedb2fbdaf35d2bbf6d18f21b22846fd5004a03da1a0b4b2dd"},
             {"host",
              "vpc-payout-history-theta-u6tts4mz6gfvzywhk2xvaq2qfa.eu-central-1.es.amazonaws.com"},
             {"x-amz-content-sha256",
              "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
             {"x-amz-date", "20201119T155150Z"},
             {"x-amz-security-token", opts[:session_token]}
           ]
  end

  #
  # Signing an AssumeRole credentials request
  #
  test "sign_v4/1 without session token" do
    opts = [
      verb: "POST",
      url: "https://sts.eu-central-1.amazonaws.com",
      content:
        "Action=AssumeRole&RoleArn=arn%3Aaws%3Aiam%3A%3A433108065205%3Arole%2Faws-test&RoleSessionName=baba&Version=2011-06-15",
      region: "eu-central-1",
      service: "sts",
      access_key_id: "AKIAWKJF5BC2ZCYNJRKB",
      secret_access_key: "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",
      type: "AWS-HMAC"
    ]

    signature =
      Mocks.DateTime.with_time(~U[2020-11-20T14:59:41Z], fn -> AwsSigner.sign_v4(opts) end)

    assert_lists_equal(signature, [
      {"authorization",
       "AWS4-HMAC-SHA256 Credential=AKIAWKJF5BC2ZCYNJRKB/20201120/eu-central-1/sts/aws4_request, " <>
         "SignedHeaders=host;x-amz-content-sha256;x-amz-date, " <>
         "Signature=23fc0649afaf88553c6cc14c29c99df88d52809ddc7f26941ac63e4ed123cca2"},
      {"host", "sts.eu-central-1.amazonaws.com"},
      {"x-amz-content-sha256",
       "97c82f20fad30eba450327f47eaa1ef39b68a3ea8a7f022852857c21e7a69159"},
      {"x-amz-date", "20201120T145941Z"}
    ])
  end
end
