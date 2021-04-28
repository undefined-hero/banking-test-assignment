defmodule ExBanking.Application do
  use Application

  def start(_type, _args) do
    children = [
      {ExBanking.DynamicSupervisor, strategy: :one_for_one, name: ExBanking.DynamicSupervisor},
      {Registry, keys: :unique, name: ExBanking.UserAccountCache}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
