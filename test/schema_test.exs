defmodule ArcTest.Ecto.Schema do
  use ExUnit.Case, async: false
  import Mock

  defmodule DummyDefinition do
    use Arc.Definition
    use Arc.Ecto.Definition
  end

  defmodule TestUser do
    use Ecto.Schema
    import Ecto.Changeset
    use Arc.Ecto.Schema

    schema "users" do
      field(:first_name, :string)
      field(:avatar, DummyDefinition.Type)
    end

    def changeset(user, params \\ :invalid) do
      user
      |> cast(params, ~w(first_name avatar)a)
      |> validate_required(:avatar)
      |> handle_attachments(params, [{:avatar, DummyDefinition}])
    end

    def path_changeset(user, params \\ :invalid) do
      user
      |> cast(params, ~w(first_name avatar)a)
      |> validate_required(:avatar)
      |> handle_attachments(params, [{:avatar, DummyDefinition}], allow_paths: true)
    end

    def changeset2(user, params \\ :invalid) do
      user
      |> cast(params, ~w(first_name avatar)a)
      |> handle_attachments(params, [{:avatar, DummyDefinition}])
    end
  end

  setup do
    defmodule DummyDefinition do
      use Arc.Definition
      use Arc.Ecto.Definition
    end

    :ok
  end

  def build_upload(path) do
    %{__struct__: Plug.Upload, path: path, file_name: Path.basename(path)}
  end

  test "supports :invalid changeset" do
    cs = TestUser.changeset(%TestUser{})
    assert cs.valid? == false
    assert cs.changes == %{}
    assert cs.errors == [avatar: {"can't be blank", [validation: :required]}]
  end

  test_with_mock "cascades storage success into a valid change", DummyDefinition,
    store: fn {%{__struct__: Plug.Upload, path: "/path/to/my/file.png", file_name: "file.png"},
               %TestUser{}} ->
      {:ok, "file.png"}
    end do
    upload = build_upload("/path/to/my/file.png")
    cs = TestUser.changeset(%TestUser{}, %{"avatar" => upload})
    assert cs.valid?
    %{file_name: "file.png", updated_at: _} = cs.changes.avatar
  end

  test_with_mock "converts changeset into schema", DummyDefinition,
    store: fn {%{__struct__: Plug.Upload, path: "/path/to/my/file.png", file_name: "file.png"},
               %TestUser{}} ->
      {:error, :invalid_file}
    end do
    upload = build_upload("/path/to/my/file.png")

    assert TestUser.changeset(%TestUser{}, %{"avatar" => upload}).valid?
  end

  test_with_mock "applies changes to schema", DummyDefinition,
    store: fn {%{__struct__: Plug.Upload, path: "/path/to/my/file.png", file_name: "file.png"},
               %TestUser{}} ->
      {:error, :invalid_file}
    end do
    upload = build_upload("/path/to/my/file.png")
    assert TestUser.changeset(%TestUser{}, %{"avatar" => upload, "first_name" => "test"}).valid?
  end

  test_with_mock "converts atom keys", DummyDefinition,
    store: fn {%{__struct__: Plug.Upload, path: "/path/to/my/file.png", file_name: "file.png"},
               %TestUser{}} ->
      {:error, :invalid_file}
    end do
    upload = build_upload("/path/to/my/file.png")
    assert TestUser.changeset(%TestUser{}, %{avatar: upload}).valid?
  end

  test_with_mock "casting nil attachments", DummyDefinition,
    store: fn {%{__struct__: Plug.Upload, path: "/path/to/my/file.png", file_name: "file.png"},
               %TestUser{}} ->
      {:ok, "file.png"}
    end do
    changeset =
      TestUser.changeset(%TestUser{}, %{"avatar" => build_upload("/path/to/my/file.png")})

    changeset = TestUser.changeset2(changeset, %{"avatar" => nil})
    assert nil == Ecto.Changeset.get_field(changeset, :avatar)
  end

  test_with_mock "allow_paths => true", DummyDefinition,
    store: fn {"/path/to/my/file.png", %TestUser{}} -> {:ok, "file.png"} end do
    changeset = TestUser.path_changeset(%TestUser{}, %{"avatar" => "/path/to/my/file.png"})

    assert changeset.valid?
  end
end
