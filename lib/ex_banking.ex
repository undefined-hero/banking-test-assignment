defmodule ExBanking do
  @moduledoc """
  Test task for Elixir developers.
  """

  use GenServer
  require Logger
  alias ExBanking.Interface

  @behaviour Interface

  @impl Interface
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

  @impl Interface
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    {user, amount} = {String.to_atom(user), amount / 1}

    try do
      check_queue_length(user)
      GenServer.call(user, {:deposit, amount, currency})
    catch
      {_user, :noproc} ->
        {:error, :user_does_not_exist}

      {_user, :too_many_requests} ->
        {:error, :too_many_requests_to_user}
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @impl Interface
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    user = String.to_atom(user)

    try do
      check_queue_length(user)
      GenServer.call(user, {:get_balance, currency})
    catch
      {_user, :noproc} ->
        {:error, :user_does_not_exist}

      {_name, :too_many_requests} ->
        {:error, :too_many_requests_to_user}
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @impl Interface
  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    {user, amount} = {String.to_atom(user), amount / 1}

    try do
      check_queue_length(user)
      GenServer.call(user, {:withdraw, amount, currency})
    catch
      {_user, :noproc} ->
        {:error, :user_does_not_exist}

      {_name, :too_many_requests} ->
        {:error, :too_many_requests_to_user}

      _error ->
        {:error, :not_enough_money}
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @impl Interface
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and
             is_binary(currency) do
    {from_user, to_user, amount} =
      {String.to_atom(from_user), String.to_atom(to_user), amount / 1}

    try do
      with :ok <- check_queue_length(from_user),
           :ok <- check_queue_length(to_user),
           {:ok, from_user_balance} <- GenServer.call(from_user, {:withdraw, amount, currency}),
           {:ok, to_user_balance} <- GenServer.call(to_user, {:deposit, amount, currency}) do
        {:ok, from_user_balance, to_user_balance}
      else
        error ->
          error
      end
    catch
      {^from_user, :noproc} ->
        {:error, :sender_does_not_exist}

      {^to_user, :noproc} ->
        {:error, :receiver_does_not_exist}

      {^from_user, :too_many_requests} ->
        {:error, :too_many_requests_to_sender}

      {^to_user, :too_many_requests} ->
        {:error, :too_many_requests_to_receiver}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  defp check_queue_length(name) do
    case GenServer.whereis(name) do
      nil ->
        throw({name, :noproc})

      pid ->
        {:ok, name} = Process.info(pid) |> Keyword.fetch(:registered_name)
        {:ok, queue_length} = Process.info(pid) |> Keyword.fetch(:message_queue_len)

        if queue_length >= 10 do
          throw({name, :too_many_requests})
        end

        :ok
    end
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
