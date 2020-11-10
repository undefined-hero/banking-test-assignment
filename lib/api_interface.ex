defmodule ExBanking.Interface do
  @moduledoc """
  API interface.
  """

  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @callback create_user(user :: String.t()) :: :ok | banking_error
  @callback deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
              {:ok, new_balance :: number} | banking_error
  @callback withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
              {:ok, new_balance :: number} | banking_error
  @callback get_balance(user :: String.t(), currency :: String.t()) ::
              {:ok, balance :: number} | banking_error
  @callback send(
              from_user :: String.t(),
              to_user :: String.t(),
              amount :: number,
              currency :: String.t()
            ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
end
