defmodule Arc.Ecto.Schema do
  defmacro __using__(_) do
    quote do
      import Arc.Ecto.Schema
    end
  end

  # maybe it's possible to avoid passing a definition by using the following:
  # definition = __MODULE__.__schema__(:type, field)
  #

  def cast_upload(changeset, definition, field) do
    Ecto.Changeset.prepare_changes(changeset, fn changeset ->
      perform_upload(changeset, definition, field)
    end)
  end

  def perform_upload(changeset, definition, field) do
    with file when not is_nil(file) <- Changeset.get_field(changeset, field),
         {:ok, uploaded_file} <- {:ok, path} = definition.store(file) do
      Ecto.Changeset.put_change(changeset, field, uploaded_file)
    else
      nil ->
        changeset

      {:error, reason} ->
        changeset.repo.rollback(reason)
        Ecto.Changeset.add_error(changeset, field, reason)
    end
  end

  # defmacro cast_attachments(changeset_or_data, params, allowed, options \\ []) do
  #   quote bind_quoted: [changeset_or_data: changeset_or_data,
  #                       params: params,
  #                       allowed: allowed,
  #                       options: options] do
  #
  #     # If given a changeset, apply the changes to obtain the underlying data
  #     scope = case changeset_or_data do
  #       %Ecto.Changeset{} -> Ecto.Changeset.apply_changes(changeset_or_data)
  #       %{__meta__: _} -> changeset_or_data
  #     end
  #
  #     # Cast supports both atom and string keys, ensure we're matching on both.
  #     allowed = Enum.map(allowed, fn key ->
  #       case key do
  #         key when is_binary(key) -> key
  #         key when is_atom(key) -> Atom.to_string(key)
  #       end
  #     end)
  #
  #     arc_params = case params do
  #       :invalid ->
  #         :invalid
  #       %{} ->
  #         params
  #         |> Arc.Ecto.Schema.convert_params_to_binary
  #         |> Map.take(allowed)
  #         |> Enum.reduce([], fn
  #           # Don't wrap nil casts in the scope object
  #           {field, nil}, fields -> [{field, nil} | fields]
  #
  #           # Allow casting Plug.Uploads
  #           {field, upload = %{__struct__: Plug.Upload}}, fields -> [{field, {upload, scope}} | fields]
  #
  #           # If casting a binary (path), ensure we've explicitly allowed paths
  #           {field, path}, fields when is_binary(path) ->
  #             if Keyword.get(options, :allow_paths, false) do
  #               [{field, {path, scope}} | fields]
  #             else
  #               fields
  #             end
  #         end)
  #         |> Enum.into(%{})
  #     end
  #
  #     cast(changeset_or_data, arc_params, allowed)
  #   end
  # end
  #
  # def convert_params_to_binary(params) do
  #   Enum.reduce(params, nil, fn
  #     {key, _value}, nil when is_binary(key) ->
  #       nil
  #
  #     {key, _value}, _ when is_binary(key) ->
  #       raise ArgumentError, "expected params to be a map with atoms or string keys, " <>
  #                            "got a map with mixed keys: #{inspect params}"
  #
  #     {key, value}, acc when is_atom(key) ->
  #       Map.put(acc || %{}, Atom.to_string(key), value)
  #
  #   end) || params
  # end
end
