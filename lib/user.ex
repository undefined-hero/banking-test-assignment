defmodule ExBanking.User do
  use GenServer
  require Logger

  def create_user(user) when is_binary(user) do
    user = String.to_atom(user)

    case GenServer.start_link(__MODULE__, {user, %{}}, name: user) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        {:error, :user_already_exists}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @impl true
  def init(account) do
    {:ok, account}
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, {user, account}) do
    {new_account, new_amount} = add_money!(account, amount, currency)

    {:reply, {:ok, new_amount}, {user, new_account}}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, {user, account}) do
    with {:ok, amount} <- Map.fetch(account, currency) do
      {:reply, {:ok, amount}, {user, account}}
    else
      :error ->
        {:reply, {:ok, 0}, {user, account}}
    end
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, {user, account}) do
    with {:ok, value} <- Map.fetch(account, currency) do
      cond do
        value >= amount ->
          {new_account, new_amount} = subtract_money!(account, amount, currency)

          {:reply, {:ok, new_amount}, {user, new_account}}

        true ->
          {:reply, {:error, :not_enough_money}, {user, account}}
      end
    else
      :error ->
        {:reply, {:error, :not_enough_money}, {user, account}}
    end
  end

  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    {user, amount} = {String.to_atom(user), amount / 1}

    try do
      GenServer.call(user, {:deposit, amount, currency})
    catch
      :exit, _reason ->
        {:error, :user_does_not_exist}
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    user = String.to_atom(user)

    try do
      GenServer.call(user, {:get_balance, currency})
    catch
      :exit, _reason ->
        {:error, :user_does_not_exist}
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    {user, amount} = {String.to_atom(user), amount / 1}

    try do
      GenServer.call(user, {:withdraw, amount, currency})
    catch
      :exit, _reason ->
        {:error, :user_does_not_exist}

      error ->
        IO.inspect(error)
        {:error, :not_enough_money}
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and
             is_binary(currency) do
    {from_user, to_user, amount} =
      {String.to_atom(from_user), String.to_atom(to_user), amount / 1}

    try do
      with {:ok, from_user_balance} <- GenServer.call(from_user, {:withdraw, amount, currency}),
           {:ok, to_user_balance} <- GenServer.call(to_user, {:deposit, amount, currency}) do
        {:ok, from_user_balance, to_user_balance}
      else
        error ->
          error
      end
    catch
      :exit, {:noproc, {GenServer, :call, [^from_user | _tail]}} ->
        {:error, :sender_does_not_exist}

      :exit, {:noproc, {GenServer, :call, [^to_user | _tail]}} ->
        GenServer.call(from_user, {:deposit, amount, currency})
        {:error, :receiver_does_not_exist}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

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
end
