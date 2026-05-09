defmodule Harbor.QueryMacros do
  @moduledoc false

  defmacro now do
    quote do
      fragment("now()")
    end
  end

  defmacro money_amount(field) do
    quote do
      fragment("(?).amount", unquote(field))
    end
  end

  defmacro lower(field) do
    quote do
      fragment("lower(?)", unquote(field))
    end
  end

  defmacro regexp_replace(field, pattern, replacement, flags) do
    quote do
      fragment(
        "regexp_replace(?, ?, ?, ?)",
        unquote(field),
        unquote(pattern),
        unquote(replacement),
        unquote(flags)
      )
    end
  end

  defmacro text_search_matches(vector, search) do
    quote do
      fragment("? @@ websearch_to_tsquery('english', ?)", unquote(vector), unquote(search))
    end
  end

  defmacro text_search_rank(vector, search) do
    quote do
      fragment(
        "ts_rank_cd(?, websearch_to_tsquery('english', ?))",
        unquote(vector),
        unquote(search)
      )
    end
  end

  defmacro trigram_match(field, search) do
    quote do
      fragment("? % ?", unquote(field), unquote(search))
    end
  end

  defmacro trigram_similarity(field, search) do
    quote do
      fragment("similarity(?, ?)", unquote(field), unquote(search))
    end
  end
end
