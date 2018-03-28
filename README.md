# Arc.Ecto NG

This is a fork from the original [arc_ecto](https://github.com/stavro/arc_ecto),
it provides an integration with [Arc](https://github.com/stavro/arc) and Ecto.

There are several reasons for this fork:

* changing the logic for correctly uploading a file. In the original implementation,
the upload happens during the `cast`ing of parameters, without checking if the
data will effectively being saved on database. So we better approach by uploading
the file during the database transaction. If for some reason the upload or database
write fails, everything is rollback-ed
* strong need for a _mantained package_, unfortunately `Arc.Ecto` wasn't integrating
PRs for more than a year

## Installation

Add the github repository to your `mix.exs` file (we'll publish a package soon):

```elixir
defp deps do
  [
    {:arc_ecto_ng, git: "https://github.com/FunkyStudioHQ/arc_ecto_ng.git"}
  ]
end

defp application do
  [applications: [:arc_ecto]]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

## Usage

### Add Arc.Ecto.Definition

Add a second using macro `use Arc.Ecto.Definition` to the top of your Arc definitions.

```elixir
defmodule MyApp.Avatar do
  use Arc.Definition
  use Arc.Ecto.Definition

  # ...
end
```

This provides a set of functions to ease integration with Arc and Ecto.  In particular:

  * Definition of a custom Ecto Type responsible for storing the images.
  * Url generation with a cache-busting timestamp query parameter

### Add a string column to your schema

Arc attachments should be stored in a string column, with a name indicative of the attachment.

```elixir
create table :users do
  add :avatar, :string
end
```

### Add your attachment to your Ecto Schema

Add a using statement `use Arc.Ecto.Schema` to the top of your ecto schema, and specify the type of the column in your schema as `MyApp.Avatar.Type`.

Attachments can subsequently be passed to Arc's storage though a Changeset `cast_attachments/3` function, following the syntax of `cast/3`

```elixir
defmodule MyApp.User do
  use MyApp.Web, :model
  use Arc.Ecto.Schema

  alias MyApp.Avatar

  schema "users" do
    field :name,   :string
    field :avatar, MyApp.Avatar.Type
  end

  @doc """
  Creates a changeset based on the `data` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(user, params \\ :invalid) do
    user
    |> cast(params, [:name])
    |> validate_required([:name, :avatar])
    |> handle_attachments(params, [{:avatar, Avatar}])
  end
end
```

### Save your attachments as normal through your controller

```elixir
  @doc """
  Given params of:

  %{
    "id" => 1,
    "user" => %{
      "avatar" => %Plug.Upload{
                    content_type: "image/png",
                    filename: "selfie.png",
                    path: "/var/folders/q0/dg42x390000gp/T//plug-1434/multipart-765369-5"}
    }
  }

  """
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Repo.get(User, id)
    changeset = User.changeset(user, user_params)

    if changeset.valid? do
      Repo.update(changeset)

      conn
      |> put_flash(:info, "User updated successfully.")
      |> redirect(to: user_path(conn, :index))
    else
      render conn, "edit.html", user: user, changeset: changeset
    end
  end
```

### Retrieve the serialized url

Both public and signed urls will include the timestamp for cache busting, and are retrieved the exact same way as using Arc directly.

```elixir
  user = Repo.get(User, 1)

  # To receive a single rendition:
  MyApp.Avatar.url({user.avatar, user}, :thumb)
    #=> "https://bucket.s3.amazonaws.com/uploads/avatars/1/thumb.png?v=63601457477"

  # To receive all renditions:
  MyApp.Avatar.urls({user.avatar, user})
    #=> %{original: "https://.../original.png?v=1234", thumb: "https://.../thumb.png?v=1234"}

  # To receive a signed url:
  MyApp.Avatar.url({user.avatar, user}, signed: true)
  MyApp.Avatar.url({user.avatar, user}, :thumb, signed: true)
```

## TODO
* refactor tests: remove mocks, add more real cases, fix warnings
* integrate [some interesting PRs](https://github.com/stavro/arc_ecto/pulls) from the original repository
* implement business logic to handle uploaded files during update or delete
* maybe choose a better name for this package
* publish the package on [hex.pm](https://hex.pm)

## Credits

[Stavro](https://github.com/stavro), author of [Arc.Ecto](https://github.com/stavro/arc_ecto).

## License

Copyright 2018 http://funky.studio

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
