class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role, default: 0
      t.text :content, null: false
      t.json :meta, default: {}

      t.timestamps
    end
  end
end
