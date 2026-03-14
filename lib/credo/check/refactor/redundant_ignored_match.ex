defmodule Credo.Check.Refactor.RedundantIgnoredMatch do
  @moduledoc """
  Flags redundant matches involving ignored variables, such as `_ = expr()` and
  function parameters like `%Product{} = _product`.
  """

  use Credo.Check,
    category: :refactor,
    base_priority: :high,
    explanations: [
      check: """
      Avoid redundant matches involving ignored variables.

      These patterns add noise without making the code clearer:

          _ = expr()

          def foo(%Product{} = _product), do: :ok

      Prefer the simpler form instead:

          expr()

          def foo(%Product{}), do: :ok
          # or, if the pattern itself is unnecessary:
          def foo(_product), do: :ok

      In general, if a value is intentionally ignored, don't bind it to an extra
      ignored variable and don't match it against an extra pattern.
      """
    ]

  @doc false
  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)

    Credo.Code.prewalk(source_file, &walk/2, ctx).issues
  end

  defp walk({definition, _meta, [head, _body]} = ast, ctx)
       when definition in [:def, :defp, :defmacro, :defmacrop] do
    ctx = Enum.reduce(function_arguments(head), ctx, &find_issue_in_argument/2)

    {ast, ctx}
  end

  defp walk({:=, _meta, [{:_, var_meta, nil}, _rhs]} = ast, ctx) do
    {ast, put_issue(ctx, ignored_assignment_issue(ctx, var_meta))}
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp find_issue_in_argument({:=, _meta, [_pattern, {name, var_meta, nil}]}, ctx) do
    if ignored_variable_name?(name) do
      put_issue(ctx, ignored_parameter_pattern_issue(ctx, var_meta, name))
    else
      ctx
    end
  end

  defp find_issue_in_argument({:=, _meta, [{name, var_meta, nil}, _pattern]}, ctx) do
    if ignored_variable_name?(name) do
      put_issue(ctx, ignored_parameter_pattern_issue(ctx, var_meta, name))
    else
      ctx
    end
  end

  defp find_issue_in_argument(_argument, ctx) do
    ctx
  end

  defp function_arguments({:when, _, [{_name, _, arguments}, _guards]}) do
    arguments || []
  end

  defp function_arguments({_name, _, arguments}) do
    arguments || []
  end

  defp ignored_variable_name?(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.starts_with?("_")
  end

  defp ignored_variable_name?(_name) do
    false
  end

  defp ignored_assignment_issue(ctx, meta) do
    format_issue(
      ctx,
      message:
        "Avoid assigning a value to `_` just to evaluate it. Call the expression directly.",
      trigger: "_ =",
      line_no: meta[:line],
      column: meta[:column]
    )
  end

  defp ignored_parameter_pattern_issue(ctx, meta, name) do
    format_issue(
      ctx,
      message:
        "Avoid matching an ignored parameter against an additional pattern. Keep either the pattern or the ignored variable, but not both.",
      trigger: Atom.to_string(name),
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
