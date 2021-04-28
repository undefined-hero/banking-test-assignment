defmodule ExBankingTest do
  use ExUnit.Case

  describe "base cases" do
    setup do
      {user, to_user} = {"foo", "bar"}
      assert {:ok, pid} = ExBanking.create_user(user)
      assert {:ok, pid2} = ExBanking.create_user(to_user)
      on_exit(fn ->
        DynamicSupervisor.terminate_child(ExBanking.DynamicSupervisor, pid)
        DynamicSupervisor.terminate_child(ExBanking.DynamicSupervisor, pid2)
      end)

      {:ok, user: user, to_user: to_user}
    end

    test ":user_already_exists", %{user: user} do
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

    test "send/4", %{user: from_user, to_user: to_user} do
      {amount, currency} = {30.0, "USD"}
      assert {:ok, ^amount} = ExBanking.deposit(from_user, amount, currency)

      assert {:ok, 10.0, 20.0} = ExBanking.send(from_user, to_user, 20, currency)
      assert {:ok, 10.0} = ExBanking.get_balance(from_user, currency)
      assert {:ok, 20.0} = ExBanking.get_balance(to_user, currency)
    end

    test "send/4 :receiver_does_not_exist", %{user: from_user} do
      {not_existed_user, amount, currency} = {"foofoo", 30.0, "USD"}
      assert {:ok, ^amount} = ExBanking.deposit(from_user, amount, currency)

      assert {:error, :receiver_does_not_exist} =
               ExBanking.send(from_user, not_existed_user, amount, currency)

      assert {:ok, 30.0} = ExBanking.get_balance(from_user, currency)
    end

    test "send/4 :sender_does_not_exist", %{to_user: to_user} do
      assert {:error, :sender_does_not_exist} = ExBanking.send("foofoo", to_user, 20, "USD")
    end

    test "send/4 :not_enough_money", %{user: from_user, to_user: to_user} do
      assert {:error, :not_enough_money} = ExBanking.send(from_user, to_user, 20, "USD")
    end
  end

  describe "" do
    test "keep state" do
      {user, amount, currency} = {"foobar", 30.0, "USD"}
      assert {:ok, pid} = ExBanking.create_user(user)
      assert %{active: 1} = DynamicSupervisor.count_children(ExBanking.DynamicSupervisor)
      assert {:ok, _amount} = ExBanking.deposit(user, amount, currency)

      assert :ok = String.to_atom(user) |> GenServer.stop(:terminate)
      assert %{active: 1} = DynamicSupervisor.count_children(ExBanking.DynamicSupervisor)
      assert {:ok, ^amount} = ExBanking.get_balance(user, currency)
    end

    test "load testing" do
      users = for i <- 1..5 do
        user = "test" <> to_string(i)
        ExBanking.create_user(user)
        ExBanking.deposit(user, 1000, "USD")
        user
      end

      send = fn users ->
        for u1 <- users, u2 <- Enum.reverse(users), do: ExBanking.send(u1, u2, 1, "USD")
      end

      1..1000
      |> Enum.map(fn _ ->
        spawn(fn ->
          receive do
            :withdraw ->
              send.(users)
              send.(users)
          end
        end)
      end)
      |> Enum.map(fn pid ->
        send(pid, :withdraw)
      end)
      Process.sleep(500)
    end
  end
end
