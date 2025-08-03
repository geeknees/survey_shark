class FixSessionsForeignKey < ActiveRecord::Migration[8.0]
  def change
    # 既存の外部キー制約を削除
    remove_foreign_key :sessions, :users if foreign_key_exists?(:sessions, :users)
    
    # user_id カラムを admin_id にリネーム
    rename_column :sessions, :user_id, :admin_id
    
    # admins テーブルへの新しい外部キー制約を追加
    add_foreign_key :sessions, :admins
  end
end
