defmodule AwsSigner.MixProject do
  use Mix.Project

  def project do
    [
      app: :aws_signer,
      version: "1.0.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      xref: [exclude: [IEx, IEx.Pry]],
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/mocks", "lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:cachex, "~> 3.3", optional: true},
      {:hackney, "~> 1.17", only: :dev},
      {:assertions, "~> 0.10", only: :test}
    ]
  end
end
