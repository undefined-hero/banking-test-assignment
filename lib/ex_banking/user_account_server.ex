defmodule ExBanking.UserAccountServer do
  use GenServer
  require Logger

  def start_link(user) do
    user = String.to_atom(user)

    case Registry.meta(ExBanking.UserAccountCache, user) do
      {:ok, account} ->
        Logger.info("User #{to_string(user)} found in cache")
        start_server(user, account)

      :error ->
        start_server(user)
    end
  end

  defp start_server(user, account \\ %{}) do
    case GenServer.start_link(__MODULE__, {user, account}, name: user) do
      {:ok, pid} ->
        Logger.info("User #{to_string(user)} created")
        {:ok, pid}

      {:error, {:already_started, _pid}} ->
        Logger.info("User #{to_string(user)} #{to_string(:user_already_exists)}")
        {:error, :user_already_exists}
    end
  end

  @impl true
  def terminate(_reason, {user, account}) do
    Logger.info "User #{user} terminated and stored to a cache"

    Registry.put_meta(ExBanking.UserAccountCache, user, account)
  end

  @impl true
  def init(account) do
    {:ok, account}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, {user, account}) do
    with {:ok, amount} <- Map.fetch(account, currency) do
      Logger.info("User #{to_string(user)} checks #{currency} balance")
      {:reply, {:ok, amount}, {user, account}}
    else
      :error ->
        Logger.info("User #{to_string(user)} checks #{currency} balance")
        {:reply, {:ok, 0}, {user, account}}
    end
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, {user, account}) do
    {new_account, new_amount} = add_money!(account, amount, currency)
    Logger.info("User #{to_string(user)} deposits #{currency}")

    {:reply, {:ok, new_amount}, {user, new_account}}
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, {user, account}) do
    with {:ok, value} <- Map.fetch(account, currency) do
      cond do
        value >= amount ->
          {new_account, new_amount} = subtract_money!(account, amount, currency)

          Logger.info("User #{to_string(user)} withdraws #{currency}")
          {:reply, {:ok, new_amount}, {user, new_account}}

        true ->
          Logger.info("User #{to_string(user)} got #{to_string(:not_enough_money)}")
          {:reply, {:error, :not_enough_money}, {user, account}}
      end
    else
      :error ->
        Logger.info("User #{to_string(user)} got #{to_string(:not_enough_money)}")
        {:reply, {:error, :not_enough_money}, {user, account}}
    end
  end

  defp add_money!(account, amount, currency) do
    {_, %{^currency => new_amount} = new_account} =
      Map.get_and_update(account, currency, fn
        nil ->
          {nil, amount}

        value ->
          {value, Float.round(value + amount, 2)}
      end)

    {new_account, new_amount}
  end

  defp subtract_money!(account, amount, currency) do
    {_, %{^currency => new_amount} = new_account} =
      Map.get_and_update(account, currency, fn
        nil ->
          {nil, amount}

        value ->
          {value, if(value >= amount, do: Float.round(value - amount, 2), else: amount)}
      end)

    {new_account, new_amount}
  end
end
