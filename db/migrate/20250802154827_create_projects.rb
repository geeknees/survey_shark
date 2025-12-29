class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.text :goal
      t.json :must_ask, default: []
      t.json :never_ask, default: []
      t.string :tone, default: "polite_soft"
      t.json :limits, default: { max_turns: 12, max_deep: 5 }
      t.string :status, default: "draft"
      t.integer :max_responses, default: 50

      t.timestamps
    end
  end
end
