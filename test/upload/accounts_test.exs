defmodule Upload.AccountsTest do
  use Upload.DataCase

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
      assert user.email == "test@example.com"
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
  end
end
