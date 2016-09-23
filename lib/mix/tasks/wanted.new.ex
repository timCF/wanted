defmodule Mix.Tasks.Wanted.New do
	use Mix.Task

  import Mix.Generator
  import Mix.Utils, only: [camelize: 1]

  @shortdoc "Creates a new Wanted project"

  @moduledoc """
  Creates a new Wanted project.
  It expects the path of the project as argument.
      mix new PATH [--module MODULE] [--app APP]
  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.
  An `--app` option can be given in order to
  name the OTP application for the project.
  A `--module` option can be given in order
  to name the modules in the generated code skeleton.
  ## Examples
      mix new hello_world
  Is equivalent to:
      mix new hello_world --module HelloWorld
  """

  @switches [app: :string, module: :string]

  @spec run(OptionParser.argv) :: :ok
  def run(argv) do
    {opts, argv} = OptionParser.parse!(argv, strict: @switches)

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use \"mix new PATH\""
      [path | _] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || camelize(app)
        check_mod_name_validity!(mod)
        check_mod_name_availability!(mod)
        File.mkdir_p!(path)
        File.cd!(path, fn -> do_generate(app, mod, path, opts) end)
    end
  end

  defp do_generate(app, mod, path, opts) do
    assigns = [app: app, mod: mod, otp_app: otp_app(mod),
               version: get_version(System.version)]

    create_file "README.md",  readme_template(assigns)
    create_file ".gitignore", gitignore_text
    create_file "mix.exs", mixfile_template(assigns)

    create_directory "config"
    create_file "config/config.exs", config_template(assigns)

    create_directory "lib"
    create_file "lib/#{app}.ex", lib_sup_template(assigns)

    create_directory "test"
    create_file "test/test_helper.exs", test_helper_template(assigns)
    create_file "test/#{app}_test.exs", test_template(assigns)

    Mix.shell.info """
    Your Mix project was created successfully.
    You can use "mix" to compile it, test it, and more:
        cd #{path}
        mix test
    Run "mix help" for more commands.
    """
  end

	defp otp_app(mod) do
		"""
		[applications: [
										:logger
									],
		mod: {#{mod}, []}]
		"""
	end

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      Mix.raise "Application name must start with a letter and have only lowercase " <>
                "letters, numbers and underscore, got: #{inspect name}" <>
                (if !from_app_flag do
                  ". The application name is inferred from the path, if you'd like to " <>
                  "explicitly name the application then use the \"--app APP\" option."
                else
                  ""
                end)
    end
  end

  defp check_mod_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_mod_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp get_version(version) do
    {:ok, version} = Version.parse(version)
    "#{version.major}.#{version.minor}" <>
      case version.pre do
        [h | _] -> "-#{h}"
        []      -> ""
      end
  end

  embed_template :readme, """
  # <%= @mod %>
  **TODO: Add description**
  <%= if @app do %>
  ## Installation
  If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:
    1. Add `<%= @app %>` to your list of dependencies in `mix.exs`:
      ```elixir
      def deps do
        [{:<%= @app %>, "~> 0.1.0"}]
      end
      ```
    2. Ensure `<%= @app %>` is started before your application:
      ```elixir
      def application do
        [applications: [:<%= @app %>]]
      end
      ```
  <% end %>
  """

  embed_text :gitignore, """
  # The directory Mix will write compiled artifacts to.
  /_build
  # If you run "mix test --cover", coverage assets end up here.
  /cover
  # The directory Mix downloads your dependencies sources to.
  /deps
  # Where 3rd-party dependencies like ExDoc output generated docs.
  /doc
  # If the VM crashes, it generates a dump, let's ignore it too.
  erl_crash.dump
  # Also ignore archive artifacts (built via "mix archive.build").
  *.ez
  """

  embed_template :mixfile, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project
    def project do
      [app: :<%= @app %>,
       version: "0.1.0",
       # elixir: "~> <%= @version %>",
       build_embedded: Mix.env == :prod,
       start_permanent: Mix.env == :prod,
       deps: deps()]
    end
    # Configuration for the OTP application
    #
    # Type "mix help compile.app" for more information
    def application do
  <%= @otp_app %>
    end
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
      []
    end
  end
  """

  embed_template :config, ~S"""
  # This file is responsible for configuring your application
  # and its dependencies with the aid of the Mix.Config module.
  use Mix.Config
  # This configuration is loaded before any dependency and is restricted
  # to this project. If another project depends on this project, this
  # file won't be loaded nor affect the parent project. For this reason,
  # if you want to provide default values for your application for
  # 3rd-party users, it should be done in your "mix.exs" file.
  # You can configure for your application as:
  #
  #     config :<%= @app %>, key: :value
  #
  # And access this configuration in your application as:
  #
  #     Application.get_env(:<%= @app %>, :key)
  #
  # Or configure a 3rd-party app:
  #
  #     config :logger, level: :info
  #
  # It is also possible to import configuration files, relative to this
  # directory. For example, you can emulate configuration per environment
  # by uncommenting the line below and defining dev.exs, test.exs and such.
  # Configuration from the imported file will override the ones defined
  # here (which is why it is important to import them last).
  #
  #     import_config "#{Mix.env}.exs"
  """

  embed_template :lib_sup, """
  defmodule <%= @mod %> do
    use Application
    # See http://elixir-lang.org/docs/stable/elixir/Application.html
    # for more information on OTP Applications
    def start(_type, _args) do
      import Supervisor.Spec, warn: false
      # Define workers and child supervisors to be supervised
      children = [
        # Starts a worker by calling: <%= @mod %>.Worker.start_link(arg1, arg2, arg3)
        # worker(<%= @mod %>.Worker, [arg1, arg2, arg3]),
      ]
      # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: <%= @mod %>.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  """

  embed_template :test, """
  defmodule <%= @mod %>Test do
    use ExUnit.Case
    doctest <%= @mod %>
    test "the truth" do
      assert 1 + 1 == 2
    end
  end
  """

  embed_template :test_helper, """
  ExUnit.start()
  """
end
