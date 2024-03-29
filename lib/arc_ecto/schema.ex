defmodule Arc.Ecto.Schema do
  alias Ecto.Changeset

  defmacro __using__(_) do
    quote do
      import Arc.Ecto.Schema
    end
  end

  def handle_attachments(changeset, params, allowed, options \\ []) do
    Changeset.prepare_changes(changeset, fn changeset ->
      changeset
      |> cast_attachments(params, allowed, options)
      |> perform_uploads(allowed)
    end)
  end

  defp perform_uploads(changeset, allowed) do
    Enum.reduce(allowed, changeset, fn {field, definition}, changeset ->
      changeset
      |> perform_upload(definition, field)
    end)
  end

  defp perform_upload(changeset, definition, field) do
    with {:ok, file} when not is_nil(file) <- validate_attachment(changeset, definition, field),
         {:ok, uploaded_file} <- store_attachment(changeset, definition, file) do
      Changeset.put_change(changeset, field, uploaded_file)
    else
      nil ->
        changeset

      {:error, %Changeset{}} ->
        changeset = Changeset.add_error(changeset, field, inspect(changeset.errors))
        changeset.repo.rollback(changeset)

      {:error, error} ->
        changeset = Changeset.add_error(changeset, field, inspect(error))
        changeset.repo.rollback(changeset)
    end
  end

  defp cast_attachments(changeset, params, allowed, options) do
    arc_allowed =
      Enum.map(allowed, fn {key, _definition} ->
        case key do
          key when is_binary(key) -> key
          key when is_atom(key) -> Atom.to_string(key)
        end
      end)

    arc_params =
      case params do
        :invalid ->
          :invalid

        %{} ->
          params
          |> convert_params_to_binary()
          |> Map.take(arc_allowed)
          |> Enum.reduce([], fn
            # Don't wrap nil casts in the scope object
            {field, nil}, fields ->
              [{field, nil} | fields]

            # Allow casting Plug.Uploads
            {field, file = %{__struct__: Plug.Upload}}, fields ->
              [{field, file} | fields]

            # If casting a binary (path), ensure we've explicitly allowed paths
            {field, path}, fields when is_binary(path) ->
              if Keyword.get(options, :allow_paths, false) do
                [{field, path} | fields]
              else
                fields
              end
          end)
          |> Enum.into(%{})
      end

    Changeset.cast(changeset, arc_params, Enum.map(arc_allowed, &String.to_existing_atom/1))
  end

  defp validate_attachment(changeset, definition, field) do
    file_field = Changeset.get_field(changeset, field)

    file =
      file_field
      |> Map.put(:filename, file_field.file_name)

    valid_upload = definition.validate({file, :ok})

    case {changeset, valid_upload} do
      {%Changeset{valid?: true}, true} ->
        {:ok, file}

      {%Changeset{valid?: true}, false} ->
        {:error, "invalid attachment"}

      _ ->
        nil
    end
  end

  defp convert_params_to_binary(params) do
    Enum.reduce(params, nil, fn
      {key, _value}, nil when is_binary(key) ->
        nil

      {key, _value}, _ when is_binary(key) ->
        raise ArgumentError,
              "expected params to be a map with atoms or string keys, " <>
                "got a map with mixed keys: #{inspect(params)}"

      {key, value}, acc when is_atom(key) ->
        Map.put(acc || %{}, Atom.to_string(key), value)
    end) || params
  end

  defp store_attachment(changeset, definition, file) do
    scope =
      case changeset do
        %Ecto.Changeset{} -> Ecto.Changeset.apply_changes(changeset)
        %{__meta__: _} -> changeset
      end

    definition.store({file, scope})
  end
end
