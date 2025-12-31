defmodule Upload.Accounts do
  import Ecto.Query, warn: false
  alias Upload.Repo
  alias Upload.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def find_or_create_user(auth) do
    uid = to_string(auth.uid)
    provider = to_string(auth.provider)

    query = from u in User, where: u.provider == ^provider and u.uid == ^uid

    case Repo.one(query) do
      nil ->
        create_user(auth)

      user ->
        {:ok, user}
    end
  end

  defp create_user(auth) do
    user_params = %{
      provider: to_string(auth.provider),
      uid: to_string(auth.uid),
      email: auth.info.email,
      name: auth.info.name || auth.info.nickname,
      avatar_url: auth.info.image,
      role: "user"
    }

    %User{}
    |> User.changeset(user_params)
    |> Repo.insert()
  end

  @doc """
  Lists all users with their sites preloaded.
  """
  def list_users do
    User
    |> preload(:sites)
    |> Repo.all()
  end

  @doc """
  Gets a user with their sites preloaded.
  """
  def get_user_with_sites!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(:sites)
  end
end
