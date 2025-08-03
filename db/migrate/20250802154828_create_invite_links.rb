class CreateInviteLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :invite_links do |t|
      t.references :project, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at
      t.boolean :reusable, default: true

      t.timestamps
    end

    add_index :invite_links, :token, unique: true
  end
end
