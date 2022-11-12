defmodule Statechart.MixProject do
  use Mix.Project

  @project_name :statechart
  @repo_url "https://github.com/jonathanchukinas/statechart"

  def project do
    [
      app: @project_name,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Tests and Checks
      dialyzer: dialyzer(),
      test_coverage: [
        summary: [threshold: 80],
        ignore_modules: [~r/Inspect.*/, Statechart.Util.DevOnlyDocs]
      ],

      # Docs
      name: "Statechart",
      source_url: @repo_url,
      docs: docs(),

      # Project
      package: package(),
      description: """
      Pure-Elixir statecharts and state machines
      """
    ]
  end

  defp package do
    [
      name: @project_name,
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/statechart/changelog.html",
        "GitHub" => @repo_url
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(env) when env in ~w/test/a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Project dependencies
      {:modified_preorder_tree, "~> 0.2.0"},
      {:typed_struct, "~> 0.2.1"},

      # Development and test dependencies
      {:dialyxir, "~>1.2", only: [:dev, :test], runtime: false},

      # Documentation dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      assets: "assets",
      authors: ["Jonathan Chukinas"],
      extras: ["CHANGELOG.md"],
      formatters: ["html"],
      groups_for_functions: [
        define: &(&1[:section] == :build),
        Manipulate: &(&1[:section] == :manipulate)
      ],
      main: "Statechart",
      nest_modules_by_prefix: [
        Statechart.Build,
        Statechart.Schema,
        Statechart.Machine
      ]
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "tmp/plts",
      plt_file: {:no_warn, "tmp/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit]
    ]
  end
end
