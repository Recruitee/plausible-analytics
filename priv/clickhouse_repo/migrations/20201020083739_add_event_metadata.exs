defmodule Plausible.ClickhouseRepo.Migrations.AddEventMetadata do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :"meta.key", :"Array(String)"
      add :"meta.value", :"Array(String)"
    end
  end
end
