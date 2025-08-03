class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :project, null: false, foreign_key: true
      t.references :participant, null: true, foreign_key: true
      t.string :state, default: "intro"
      t.datetime :started_at
      t.datetime :finished_at
      t.string :ip
      t.text :user_agent

      t.timestamps
    end
  end
end
