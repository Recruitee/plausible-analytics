defmodule Plausible.ClickhouseRepo.Migrations.AddContractId do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:contract_id, :string)
    end

    alter table(:sessions) do
      add(:contract_id, :string)
    end
  end
end
