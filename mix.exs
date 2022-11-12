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
      dialyzer: dialyzer(),

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
        # TODO add
        "Changelog" => "https://hexdocs.pm/statechart/changelog.html"
        "GitHub" => @repo_url
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(env) when env in ~w/dev test/a, do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Project dependencies
      {:modified_preorder_tree, "~> 0.1.1"},
      {:typed_struct, "~> 0.2.1"},

      # Development and test dependencies
      {:dialyxir, "~>1.2", only: [:dev, :test], runtime: false},
      {:stream_data, "~>0.5", only: [:dev, :test]},

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
        DEFINE: &(&1[:section] == :build),
        MANIPULATE: &(&1[:section] == :manipulate)
      ],
      # groups_for_modules: [
      #   # API: [
      #   #   Statechart,
      #   #   StatechartError
      #   # ],
      #   Machine: ~r/Statechart.Machine/,
      #   Schema: ~r/Statechart.Schema/,
      #   Build: ~r/Statechart.Build/,
      #   Transitions: ~r/Statechart.Transitions/,
      #   Utility: ~r/Statechart.Utility/,
      #   All: ~r/.*/
      # ],
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
      plt_file: {:no_warn, "tmp/plts/dialyzer.plt"}
    ]
  end
end
