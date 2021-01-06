defmodule Double.Mixfile do
  use Mix.Project
  @version "0.8.0"

  def project do
    [
      app: :double,
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}",
        source_url: "https://github.com/sonerdy/double"
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger],
      mod: {Double.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
      {:credo, "~> 0.7.2", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Double is a simple library to help build injectable dependencies for your tests.
    It does NOT override behavior of existing modules or functions.
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :double,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Brandon Joyce"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/sonerdy/double",
        "Docs" => "https://github.com/sonerdy/double"
      }
    ]
  end
end
