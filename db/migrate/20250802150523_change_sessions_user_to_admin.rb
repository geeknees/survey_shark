class ChangeSessionsUserToAdmin < ActiveRecord::Migration[8.0]
  def change
    rename_column :sessions, :user_id, :admin_id
    remove_foreign_key :sessions, :users if foreign_key_exists?(:sessions, :users)
    add_foreign_key :sessions, :admins
  end
end
