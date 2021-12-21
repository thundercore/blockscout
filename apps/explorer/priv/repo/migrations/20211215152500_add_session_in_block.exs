defmodule Explorer.Repo.Migrations.AddEpochInfo do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:session, :integer, null: true)
      add(:blocksn_e, :integer, null: true)
      add(:blocksn_s, :integer, null: true)
    end
  end
end
