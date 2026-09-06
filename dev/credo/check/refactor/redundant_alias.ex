defmodule Credo.Check.Refactor.RedundantAlias do
  @moduledoc """
  Flags aliases that are already introduced by an earlier `use` macro.
  """

  use Credo.Check,
    category: :refactor,
    base_priority: :high,
    explanations: [
      check: """
      A `use` macro can introduce aliases into the calling module. Repeating one
      of those aliases adds noise and can obscure what the macro provides.

          use Harbor.Schema
          alias Harbor.Accounts.Scope

      Since `Harbor.Schema.__using__/1` already aliases `Harbor.Accounts.Scope`,
      remove the explicit alias.
      """
    ]

  @max_use_expansion_depth 10

  @doc false
  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)

    Credo.Code.prewalk(source_file, &walk/2, ctx).issues
  end

  defp walk({:defmodule, meta, [module_ast, body]} = ast, ctx) when is_list(body) do
    case Keyword.fetch(body, :do) do
      {:ok, module_body} ->
        env = macro_env(ctx.source_file.filename, module_ast, meta)
        {_state, ctx} = inspect_expressions(module_body, %{env: env, use_aliases: %{}}, ctx)
        {ast, ctx}

      :error ->
        {ast, ctx}
    end
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp inspect_expressions(ast, state, ctx) do
    ast
    |> expressions()
    |> Enum.reduce({state, ctx}, &inspect_expression/2)
  end

  defp inspect_expression({:alias, meta, arguments}, {state, ctx}) do
    {bindings, env} = alias_bindings(arguments, state.env, meta)
    ctx = Enum.reduce(bindings, ctx, &find_redundant_alias(&1, &2, state.use_aliases))
    use_aliases = Enum.reduce(bindings, state.use_aliases, &Map.delete(&2, &1.name))

    {%{state | env: env, use_aliases: use_aliases}, ctx}
  end

  defp inspect_expression({:use, meta, arguments}, {state, ctx}) do
    env = %{state.env | line: meta[:line] || state.env.line}

    case aliases_from_use(arguments, env, [], 0) do
      {:ok, used_module, aliases, env} ->
        use_aliases =
          Enum.reduce(aliases, state.use_aliases, fn {name, binding}, use_aliases ->
            Map.put(use_aliases, name, {binding.module, used_module})
          end)

        {%{state | env: env, use_aliases: use_aliases}, ctx}

      :error ->
        {state, ctx}
    end
  end

  defp inspect_expression(_ast, state_and_ctx) do
    state_and_ctx
  end

  defp find_redundant_alias(binding, ctx, use_aliases) do
    case Map.get(use_aliases, binding.name) do
      {module, used_module} when module == binding.module ->
        put_issue(ctx, redundant_alias_issue(ctx, binding, used_module))

      _other ->
        ctx
    end
  end

  defp aliases_from_use(arguments, env, seen, depth) do
    with true <- depth < @max_use_expansion_depth,
         {:ok, module_ast, opts} <- use_arguments(arguments),
         {:ok, used_module} <- expand_safely(fn -> Macro.expand(module_ast, env) end),
         true <- is_atom(used_module),
         expansion_key = {used_module, Macro.to_string(opts)},
         false <- expansion_key in seen,
         true <- Code.ensure_loaded?(used_module),
         true <- macro_exported?(used_module, :__using__, 1),
         env = %{env | requires: Enum.uniq([used_module | env.requires])},
         call = {{:., [], [used_module, :__using__]}, [], [opts]},
         {:ok, expansion} <- expand_safely(fn -> Macro.expand_once(call, env) end) do
      {aliases, env} =
        injected_aliases(expansion, env, [expansion_key | seen], depth + 1)

      {:ok, used_module, aliases, env}
    else
      _other -> :error
    end
  end

  defp use_arguments([module_ast]), do: {:ok, module_ast, []}
  defp use_arguments([module_ast, opts]), do: {:ok, module_ast, opts}
  defp use_arguments(_arguments), do: :error

  defp injected_aliases(ast, env, seen, depth) do
    ast
    |> expressions()
    |> Enum.reduce({%{}, env}, fn
      {:alias, meta, arguments}, {aliases, env} ->
        {bindings, env} = alias_bindings(arguments, env, meta)
        aliases = Enum.reduce(bindings, aliases, &Map.put(&2, &1.name, &1))

        {aliases, env}

      {:use, meta, arguments}, {aliases, env} ->
        env = %{env | line: meta[:line] || env.line}

        case aliases_from_use(arguments, env, seen, depth) do
          {:ok, _used_module, nested_aliases, env} ->
            {Map.merge(aliases, nested_aliases), env}

          :error ->
            {aliases, env}
        end

      _ast, accumulator ->
        accumulator
    end)
  end

  defp alias_bindings(arguments, env, fallback_meta) do
    {bindings, env} =
      arguments
      |> alias_directives(env, fallback_meta)
      |> Enum.map_reduce(env, fn directive, env ->
        case define_alias(directive, env) do
          {:ok, binding, env} -> {binding, env}
          :error -> {nil, env}
        end
      end)

    {Enum.reject(bindings, &is_nil/1), env}
  end

  defp alias_directives(
         [{{:., _, [base_ast, :{}]}, _, children} | rest],
         env,
         _fallback_meta
       ) do
    opts = List.first(rest) || []

    with {:ok, base} <- expand_safely(fn -> Macro.expand(base_ast, env) end),
         true <- is_atom(base) do
      Enum.flat_map(children, &multi_alias_directive(&1, base, opts, env))
    else
      _error -> []
    end
  end

  defp alias_directives([module_ast | rest], env, fallback_meta) do
    case expand_safely(fn -> Macro.expand(module_ast, env) end) do
      {:ok, module} when is_atom(module) ->
        [
          %{
            module: module,
            meta: ast_meta(module_ast, fallback_meta),
            opts: List.first(rest) || [],
            trigger: Macro.to_string(module_ast)
          }
        ]

      _error ->
        []
    end
  end

  defp alias_directives(_arguments, _env, _fallback_meta), do: []

  defp multi_alias_directive({:__aliases__, meta, parts} = ast, base, opts, env) do
    alias_ast = {:__aliases__, meta, [base | parts]}

    case expand_safely(fn -> Macro.expand(alias_ast, %{env | aliases: []}) end) do
      {:ok, module} when is_atom(module) ->
        [%{module: module, meta: meta, opts: opts, trigger: Macro.to_string(ast)}]

      _error ->
        []
    end
  end

  defp multi_alias_directive(_ast, _base, _opts, _env), do: []

  defp define_alias(directive, env) do
    empty_env = %{env | aliases: [], macro_aliases: []}

    with {:ok, opts} <- alias_options(directive.opts, env),
         {:ok, alias_env} <-
           Macro.Env.define_alias(empty_env, directive.meta, directive.module, opts),
         [{name, module}] <- alias_env.aliases,
         {:ok, env} <- Macro.Env.define_alias(env, directive.meta, directive.module, opts) do
      binding = %{
        name: name,
        module: module,
        meta: directive.meta,
        trigger: directive.trigger
      }

      {:ok, binding, env}
    else
      _other -> :error
    end
  end

  defp alias_options(opts, env) when is_list(opts) do
    case Keyword.fetch(opts, :as) do
      {:ok, as_ast} -> expand_as_option(opts, as_ast, env)
      :error -> {:ok, Keyword.put(opts, :trace, false)}
    end
  end

  defp alias_options(_opts, _env), do: :error

  defp expand_as_option(opts, as_ast, env) do
    with {:ok, as} <- expand_safely(fn -> Macro.expand(as_ast, %{env | aliases: []}) end) do
      opts = Keyword.put(opts, :as, as)
      {:ok, Keyword.put(opts, :trace, false)}
    end
  end

  defp expand_safely(expand) do
    {:ok, expand.()}
  rescue
    _exception -> :error
  catch
    _kind, _reason -> :error
  end

  defp expressions({:__block__, _meta, expressions}) do
    Enum.flat_map(expressions, &expressions/1)
  end

  defp expressions(ast), do: [ast]

  defp ast_meta({_name, meta, _arguments}, _fallback_meta) when is_list(meta), do: meta
  defp ast_meta(_ast, fallback_meta), do: fallback_meta

  defp macro_env(filename, module_ast, meta) do
    env = %{__ENV__ | aliases: []}
    module = Macro.expand(module_ast, env)

    %{
      env
      | context: nil,
        context_modules: [module],
        file: filename || "nofile",
        function: nil,
        line: meta[:line] || 1,
        module: module,
        requires: []
    }
  end

  defp redundant_alias_issue(ctx, binding, used_module) do
    format_issue(
      ctx,
      message:
        "#{inspect(binding.module)} is already aliased as #{inspect(binding.name)} by use #{inspect(used_module)}.",
      trigger: binding.trigger,
      line_no: binding.meta[:line],
      column: binding.meta[:column]
    )
  end
end
