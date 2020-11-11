defmodule ExBankingTest do
  use ExUnit.Case

  test ":user_already_exists" do
    user = "foobar"

    assert :ok = ExBanking.create_user(user)
    assert {:error, :user_already_exists} = ExBanking.create_user(user)
  end

  test ":wrong_arguments" do
    assert {:error, :wrong_arguments} = ExBanking.create_user(200)
    assert {:error, :wrong_arguments} = ExBanking.deposit(0000, 200, "USD")
    assert {:error, :wrong_arguments} = ExBanking.get_balance("user", 8888)
    assert {:error, :wrong_arguments} = ExBanking.withdraw("user", "TEST", "USD")
    assert {:error, :wrong_arguments} = ExBanking.send("user", 200, 200, "USD")

    assert {:error, :wrong_arguments} = ExBanking.deposit("user", -200, "USD")
    assert {:error, :wrong_arguments} = ExBanking.withdraw("user", -200, "USD")
    assert {:error, :wrong_arguments} = ExBanking.send("user", "user2", -200, "USD")
  end

  test ":user_does_not_exist" do
    assert {:error, :user_does_not_exist} = ExBanking.deposit("test", 10, "RUB")
    assert {:error, :user_does_not_exist} = ExBanking.get_balance("test", "RUB")
    assert {:error, :user_does_not_exist} = ExBanking.withdraw("test", 10, "RUB")
  end

  describe "base cases" do
    setup do
      user = "foobar"

      assert :ok = ExBanking.create_user(user)
      {:ok, user: user}
    end

    test "deposit/3", %{user: user} do
      amount = 30.0

      assert {:ok, ^amount} = ExBanking.deposit(user, amount, "USD")
      assert {:ok, ^amount} = ExBanking.deposit(user, amount, "EUR")
    end

    test "get_balance/2", %{user: user} do
      {amount, currency} = {200.0, "USD"}

      assert {:ok, 0} = ExBanking.get_balance(user, currency)
      assert {:ok, ^amount} = ExBanking.deposit(user, amount, currency)
      assert {:ok, ^amount} = ExBanking.get_balance(user, currency)
    end

    test "withdraw/3", %{user: user} do
      {amount, currency} = {20.95, "USD"}
      assert {:ok, ^amount} = ExBanking.deposit(user, amount, currency)
      assert {:ok, 10.95} = ExBanking.withdraw(user, 10, currency)
      assert {:error, :not_enough_money} = ExBanking.withdraw(user, 11, currency)
      assert {:ok, 0.0} = ExBanking.withdraw(user, 10.95, currency)
      assert {:error, :not_enough_money} = ExBanking.withdraw(user, 10, "EUR")
    end

    test "send/4", %{user: from_user} do
      {to_user, amount, currency} = {"foo", 30.0, "USD"}
      assert :ok = ExBanking.create_user(to_user)
      assert {:ok, ^amount} = ExBanking.deposit(from_user, amount, currency)

      assert {:ok, 10.0, 20.0} = ExBanking.send(from_user, to_user, 20, currency)
      assert {:ok, 10.0} = ExBanking.get_balance(from_user, currency)
      assert {:ok, 20.0} = ExBanking.get_balance(to_user, currency)
    end

    test "send/4 :receiver_does_not_exist", %{user: from_user} do
      {to_user, amount, currency} = {"foofoo", 30.0, "USD"}
      assert {:ok, ^amount} = ExBanking.deposit(from_user, amount, currency)

      assert {:error, :receiver_does_not_exist} =
               ExBanking.send(from_user, to_user, amount, currency)

      assert {:ok, 30.0} = ExBanking.get_balance(from_user, currency)
    end

    test "send/4 :sender_does_not_exist", %{user: to_user} do
      assert {:error, :sender_does_not_exist} = ExBanking.send("foofoo", to_user, 20, "USD")
    end

    test "send/4 :not_enough_money", %{user: from_user} do
      to_user = "foo_bar"
      assert :ok = ExBanking.create_user(to_user)

      assert {:error, :not_enough_money} = ExBanking.send(from_user, to_user, 20, "USD")
    end
  end
end
