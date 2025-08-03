class CreateParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :participants do |t|
      t.references :project, null: false, foreign_key: true
      t.string :anon_hash
      t.integer :age
      t.json :custom_attributes, default: {}

      t.timestamps
    end

    add_index :participants, :anon_hash
  end
end
