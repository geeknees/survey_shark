class CreateInsightCards < ActiveRecord::Migration[8.0]
  def change
    create_table :insight_cards do |t|
      t.references :project, null: false, foreign_key: true
      t.references :conversation, null: true, foreign_key: true
      t.string :theme
      t.text :jtbds
      t.json :evidence, default: []
      t.integer :severity
      t.integer :freq_conversations
      t.integer :freq_messages
      t.string :confidence_label

      t.timestamps
    end
  end
end
