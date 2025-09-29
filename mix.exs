defmodule Membrane.Subtitles.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_subtitles_plugin,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: ["mneme.test": :test, "mneme.watch": :test]
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
      {:membrane_core, "~> 1.1"},
      {:membrane_text_format, "~> 1.0"},
      {:membrane_file_plugin, "~> 0.17"},
      {:kim_subtitle, "~> 0.1"},
      {:mneme, ">= 0.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
