defmodule EMQXConnectorJWT.MixProject do
  use Mix.Project
  alias EMQXUmbrella.MixProject, as: UMP

  def project do
    [
      app: :emqx_connector_jwt,
      version: "0.1.0",
      build_path: "../../_build",
      erlc_options: UMP.erlc_options(),
      erlc_paths: UMP.erlc_paths(),
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: UMP.extra_applications(),
      mod: {:emqx_connector_jwt_app, []}
    ]
  end

  def deps() do
    [
      {:emqx_resource, in_umbrella: true},
      UMP.common_dep(:jose),
    ]
  end
end
