defmodule AwsSigner.MixProject do
  use Mix.Project

  def project do
    [
      app: :aws_signer,
      version: "1.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      xref: [exclude: [IEx, IEx.Pry]],
      deps: deps(),
      name: "Tesla AWS Signer",
      source_url: "https://github.com/smanolloff/tesla-aws-signer"
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/mocks", "lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "A Tesla plug for signing HTTP requests with AWS Signature Version 4."
  end

  defp package() do
    [
      files: ~w(lib CHANGELOG mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/smanolloff/tesla-aws-signer"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.3"},
      {:jason, ">= 1.0.0"},
      {:hackney, "~> 1.17", only: :dev},
      {:assertions, "~> 0.10", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
