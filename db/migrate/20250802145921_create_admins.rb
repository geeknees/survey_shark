class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins do |t|
      t.string :email_address
      t.string :password_digest

      t.timestamps
    end
    add_index :admins, :email_address, unique: true
  end
end
