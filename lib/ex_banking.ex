defmodule ExBanking do
  @moduledoc """
  Test task for Elixir developers.
  """

  require Logger
  alias ExBanking.Interface

  @behaviour Interface

  @impl Interface
  def create_user(user) when is_binary(user) do
    DynamicSupervisor.start_child(ExBanking.DynamicSupervisor, {ExBanking.UserAccountServer, user})
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @impl Interface
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) and amount >= 0 do
    with {user, amount} <- {String.to_atom(user), amount / 1},
      :ok <- check_queue_length(user) do
      GenServer.call(user, {:deposit, amount, currency})
    else
      {_user, :noproc} ->
        {:error, :user_does_not_exist}

      {_user, :too_many_requests} ->
        {:error, :too_many_requests_to_user}
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @impl Interface
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    with user <- String.to_atom(user),
      :ok <- check_queue_length(user) do
      GenServer.call(user, {:get_balance, currency})
    else
      {_user, :noproc} ->
        {:error, :user_does_not_exist}

      {_name, :too_many_requests} ->
        {:error, :too_many_requests_to_user}
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @impl Interface
  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) and amount >= 0 do
    with {user, amount} <- {String.to_atom(user), amount / 1},
      :ok <- check_queue_length(user) do
      GenServer.call(user, {:withdraw, amount, currency})
    else
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
             is_binary(currency) and amount >= 0 do
    {from_user, to_user, amount} =
      {String.to_atom(from_user), String.to_atom(to_user), amount / 1}

    with :ok <- check_queue_length(from_user),
          :ok <- check_queue_length(to_user),
          {:ok, from_user_balance} <- GenServer.call(from_user, {:withdraw, amount, currency}),
          {:ok, to_user_balance} <- GenServer.call(to_user, {:deposit, amount, currency}) do
      Logger.info("User #{to_string(from_user)} transfers #{currency} to #{to_string(to_user)}")

      {:ok, from_user_balance, to_user_balance}
    else
      {^from_user, :noproc} ->
        {:error, :sender_does_not_exist}

      {^to_user, :noproc} ->
        {:error, :receiver_does_not_exist}

      {^from_user, :too_many_requests} ->
        {:error, :too_many_requests_to_sender}

      {^to_user, :too_many_requests} ->
        {:error, :too_many_requests_to_receiver}

      error ->
        error
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  defp check_queue_length(name) do
    case GenServer.whereis(name) do
      nil ->
        {name, :noproc}

      pid ->
        {:ok, name} = Process.info(pid) |> Keyword.fetch(:registered_name)
        {:ok, queue_length} = Process.info(pid) |> Keyword.fetch(:message_queue_len)

        if queue_length >= 10 do
          {name, :too_many_requests}
        else
          :ok
        end
    end
  end
end
