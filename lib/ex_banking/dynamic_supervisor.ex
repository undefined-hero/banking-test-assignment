defmodule ExBanking.DynamicSupervisor do

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    Logger.info("#{__MODULE__} starts")
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
