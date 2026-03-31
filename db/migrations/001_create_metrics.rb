Sequel.migration do
  change do
    create_table(:metrics) do
      primary_key :id
      DateTime :datetime, null: false, default: Sequel::CURRENT_TIMESTAMP
      String :name, null: false
      Float :value, null: false

      index [:name, :datetime], unique: true
    end
  end
end
