class AddMetaToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :meta, :json, default: {}
  end
end
