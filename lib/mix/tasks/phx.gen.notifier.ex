defmodule Mix.Tasks.Phx.Gen.Notifier do
  @shortdoc "Generates a notifier to send emails using the mailer"

  @moduledoc """
  Generates a notifier to send emails using the mailer

      mix phx.gen.notifier Accounts User welcome_user reset_password confirmation_instructions

  This task expects a context module name, followed by a
  notifier name and one or more message names. Messages
  are the functions that will be created prefixed by "deliver",
  so the message name should be "snake_case" without punctuation.

  Note that this task expects that you have a mailer defined
  as "YourApp.Mailer". Check the `mix phx.new` task for more details.
  """

  use Mix.Task

  @switches [
    context: :boolean,
    context_app: :string,
    prefix: :string
  ]

  @default_opts [context: true]

  alias Mix.Phoenix.Context

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.notifier must be invoked from within your *_web application root directory"
      )
    end

    {context, notifier_module, messages} = build(args)

    inflections = Mix.Phoenix.inflect(notifier_module)

    binding = [
      context: context,
      inflections: inflections,
      notifier_messages: messages
    ]

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context, binding)

    copy_new_files(context, binding, paths)
  end

  @doc false
  def build(args, help \\ __MODULE__) do
    {opts, parsed, _} = parse_opts(args)
    [context_name, notifier_name | notifier_messages] = validate_args!(parsed, help)

    notifier_module = inspect(Module.concat(context_name, notifier_name))
    context = Context.new(context_name, opts)

    {context, notifier_module, notifier_messages}
  end

  defp parse_opts(args) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)

    merged_opts =
      @default_opts
      |> Keyword.merge(opts)
      |> put_context_app(opts[:context_app])

    {merged_opts, parsed, invalid}
  end

  defp put_context_app(opts, nil), do: opts

  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  defp validate_args!([context, notifier | messages] = args, help) do
    cond do
      not Context.valid?(context) ->
        help.raise_with_help(
          "Expected the context, #{inspect(context)}, to be a valid module name"
        )

      not valid_notifier?(notifier) ->
        help.raise_with_help(
          "Expected the notifier, #{inspect(notifier)}, to be a valid module name"
        )

      context == Mix.Phoenix.base() ->
        help.raise_with_help(
          "Cannot generate context #{context} because it has the same name as the application"
        )

      notifier == Mix.Phoenix.base() ->
        help.raise_with_help(
          "Cannot generate notifier #{notifier} because it has the same name as the application"
        )

      Enum.any?(messages, &(!valid_message?(&1))) ->
        help.raise_with_help(
          "Cannot generate notifier #{inspect(notifier)} because one of the messages is invalid: #{Enum.map_join(messages, ", ", &inspect/1)}"
        )

      true ->
        args
    end
  end

  defp validate_args!(_, help) do
    help.raise_with_help("Invalid arguments")
  end

  defp valid_notifier?(notifier) do
    notifier =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  defp valid_message?(message_name) do
    message_name =~ ~r/^[a-z]+(\_[a-z0-9]+)*$/
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix phx.gen.notifier expects a context module name, followed by a
    notifier name and one or more message names. Messages are the
    functions that will be created prefixed by "deliver", so the message
    name should be "snake_case" without punctuation.
    For example:

        mix phx.gen.notifier Accounts User welcome reset_password

    In this example the notifier will be called `UserNotifier` inside
    the Accounts context. The functions `deliver_welcome/1` and
    `reset_password/1` will be created inside this notifier.
    """)
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context, binding)

    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.notifier", binding, files)

    context
  end

  defp files_to_be_generated(%Context{} = context, binding) do
    singular = binding[:inflections][:singular]

    [
      {:eex, "notifier.ex", Path.join([context.dir, "#{singular}_notifier.ex"])},
      {:eex, "notifier_test.exs", Path.join([context.test_dir, "#{singular}_notifier_test.exs"])}
    ]
  end

  defp prompt_for_conflicts(context, binding) do
    context
    |> files_to_be_generated(binding)
    |> Mix.Phoenix.prompt_for_conflicts()
  end
end
