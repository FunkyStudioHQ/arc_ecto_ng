defmodule Arc.Ecto.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :arc_ecto_ng,
      version: @version,
      elixir: "~> 1.5",
      deps: deps(),

      # Hex
      description: description(),
      package: package()
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :arc]]
  end

  defp description do
    """
    Another integration for Arc and Ecto.
    """
  end

  defp package do
    [
      maintainers: ["Andrea Pavoni"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/FunkyStudioHQ/arc_ecto_ng"},
      files: ~w(mix.exs README.md lib)
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:arc, "~> 0.8.0"},
      {:ecto, "~> 2.1"},
      {:mock, "~> 0.3.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
