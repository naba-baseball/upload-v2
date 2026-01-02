defmodule Upload.AccountsTest do
  use Upload.DataCase

  import Upload.AccountsFixtures
  import Upload.SitesFixtures

  alias Upload.Accounts

  describe "find_or_create_user/1" do
    test "creates a new user when one doesn't exist" do
      auth = %{
        provider: :discord,
        uid: "12345",
        info: %{
          email: "test@example.com",
          name: "Test User",
          nickname: "testuser",
          image: "http://example.com/avatar.jpg"
        }
      }

      assert {:ok, user} = Accounts.find_or_create_user(auth)
      assert user.uid == "12345"
      assert user.provider == "discord"
      assert user.email == "test@example.com"
      assert user.name == "Test User"
      assert user.avatar_url == "http://example.com/avatar.jpg"
      assert user.role == "user"
    end

    test "returns existing user when one exists" do
      auth = %{
        provider: :discord,
        uid: "12345",
        info: %{
          email: "test@example.com",
          name: "Test User",
          nickname: "testuser",
          image: "http://example.com/avatar.jpg"
        }
      }

      {:ok, user1} = Accounts.find_or_create_user(auth)
      {:ok, user2} = Accounts.find_or_create_user(auth)

      assert user1.id == user2.id
    end

    test "sets default role to 'user'" do
      auth = %{
        provider: :github,
        uid: "67890",
        info: %{
          email: "another@example.com",
          name: "Another User",
          nickname: "anotheruser",
          image: "http://example.com/another.jpg"
        }
      }

      {:ok, user} = Accounts.find_or_create_user(auth)
      assert user.role == "user"
    end

    test "uses nickname when name is not provided" do
      auth = %{
        provider: :github,
        uid: "11111",
        info: %{
          email: "nick@example.com",
          nickname: "coolnickname",
          image: "http://example.com/nick.jpg"
        }
      }

      {:ok, user} = Accounts.find_or_create_user(auth)
      assert user.name == "coolnickname"
    end

    test "provider and uid are converted to strings" do
      auth = %{
        provider: :discord,
        uid: 123_456,
        info: %{
          email: "test@example.com",
          name: "Test User",
          image: "http://example.com/avatar.jpg"
        }
      }

      {:ok, user} = Accounts.find_or_create_user(auth)
      assert user.provider == "discord"
      assert user.uid == "123456"
    end
  end

  describe "list_users/0" do
    test "returns all users" do
      user1 = user_fixture()
      user2 = user_fixture()

      users = Accounts.list_users()

      assert length(users) >= 2
      assert Enum.any?(users, &(&1.id == user1.id))
      assert Enum.any?(users, &(&1.id == user2.id))
    end

    test "preloads sites association" do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      found_user = Enum.find(Accounts.list_users(), &(&1.id == user.id))

      assert Ecto.assoc_loaded?(found_user.sites)
    end

    test "handles users with no sites" do
      user = user_fixture()

      found_user = Enum.find(Accounts.list_users(), &(&1.id == user.id))

      assert Ecto.assoc_loaded?(found_user.sites)
      assert found_user.sites == []
    end

    test "handles users with multiple sites" do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      found_user = Enum.find(Accounts.list_users(), &(&1.id == user.id))

      assert Ecto.assoc_loaded?(found_user.sites)
      assert length(found_user.sites) == 2
    end
  end

  describe "get_user_with_sites!/1" do
    test "returns user with sites preloaded" do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      fetched_user = Accounts.get_user_with_sites!(user.id)

      assert fetched_user.id == user.id
      assert Ecto.assoc_loaded?(fetched_user.sites)
      assert length(fetched_user.sites) == 2
    end

    test "returns user with empty sites list when no sites assigned" do
      user = user_fixture()

      fetched_user = Accounts.get_user_with_sites!(user.id)

      assert fetched_user.id == user.id
      assert Ecto.assoc_loaded?(fetched_user.sites)
      assert fetched_user.sites == []
    end

    test "raises Ecto.NoResultsError when user does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user_with_sites!(999_999)
      end
    end
  end

  describe "get_user!/1" do
    test "returns the user with given id" do
      user = user_fixture()
      fetched_user = Accounts.get_user!(user.id)

      assert fetched_user.id == user.id
      assert fetched_user.email == user.email
    end

    test "raises when user does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(999_999)
      end
    end
  end

  describe "get_user/1" do
    test "returns the user with given id" do
      user = user_fixture()
      fetched_user = Accounts.get_user(user.id)

      assert fetched_user.id == user.id
    end

    test "returns nil when user does not exist" do
      assert Accounts.get_user(999_999) == nil
    end
  end
end
