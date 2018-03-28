defmodule Arc.Ecto.Schema do
  defmacro __using__(_) do
    quote do
      # import Arc.Ecto.Schema
      def handle_attachments(changeset, params, allowed, options \\ []) do
        Ecto.Changeset.prepare_changes(changeset, fn changeset ->
          changeset
          |> cast_uploads(params, allowed, options)
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
        with {:ok, file} when not is_nil(file) <- validate_upload(changeset, definition, field),
             {:ok, uploaded_file} <- definition.store(file) do
          Ecto.Changeset.put_change(changeset, field, uploaded_file)
        else
          nil ->
            changeset

          {:error, reason} ->
            changeset.repo.rollback(reason)
            Ecto.Changeset.add_error(changeset, field, reason)
        end
      end

      defp cast_uploads(changeset, params, allowed, options) do
        scope =
          case changeset do
            %Ecto.Changeset{} -> Ecto.Changeset.apply_changes(changeset)
            %{__meta__: _} -> changeset
          end

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
                {field, upload = %{__struct__: Plug.Upload}}, fields ->
                  [{field, {upload, scope}} | fields]

                # If casting a binary (path), ensure we've explicitly allowed paths
                {field, path}, fields when is_binary(path) ->
                  if Keyword.get(options, :allow_paths, false) do
                    [{field, {path, scope}} | fields]
                  else
                    fields
                  end
              end)
              |> Enum.to(%{})
          end

        cast(changeset, arc_params, arc_allowed)
      end

      defp validate_upload(changeset, definition, field) do
        file =
          Changeset.get_field(changeset, field)
          |> Arc.File.new()

        valid_upload = definition.validate({file, :ok})

        case {changeset, valid_upload} do
          {%Ecto.Changeset{valid?: true}, true} ->
            {:ok, file}

          {%Ecto.Changeset{valid?: true}, false} ->
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
    end
  end
end
