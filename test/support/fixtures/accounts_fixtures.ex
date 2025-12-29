defmodule Upload.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Upload.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        avatar_url: "http://example.com/avatar.png",
        email: "some-email-#{System.unique_integer([:positive])}@example.com",
        name: "some name",
        provider: "discord",
        uid: "some-uid-#{System.unique_integer([:positive])}",
        role: "user"
      })
      |> create_user_direct()

    user
  end

  def admin_fixture(attrs \\ %{}) do
    user_fixture(Map.merge(attrs, %{role: "admin"}))
  end

  # Helper to bypass the find_or_create logic if we just want a raw insert
  # or we can reuse the logic in Accounts if we exposed a create_user.
  # Since create_user is private in Accounts, we'll replicate the insertion here 
  # or rely on Repo directly for fixtures to be fast and independent.
  defp create_user_direct(attrs) do
    %Upload.Accounts.User{}
    |> Upload.Accounts.User.changeset(attrs)
    |> Upload.Repo.insert()
  end
end
