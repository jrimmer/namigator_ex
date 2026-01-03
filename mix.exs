defmodule Namigator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jrimmer/namigator_ex"

  def project do
    [
      app: :namigator,
      version: @version,
      elixir: "~> 1.15",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.8", runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir bindings for the namigator pathfinding library.

    Provides navigation mesh (navmesh) pathfinding capabilities for World of Warcraft
    server emulators. Uses Fine for NIF bindings to the C++ namigator library with
    Recast/Detour for navigation mesh operations.
    """
  end

  defp package do
    [
      files: ["lib", "c_src", "priv/.gitkeep", "Makefile", "mix.exs", "README.md", "LICENSE"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "namigator" => "https://github.com/namreeb/namigator"
      },
      maintainers: ["jrimmer"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
