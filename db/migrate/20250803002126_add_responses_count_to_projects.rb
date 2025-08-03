class AddResponsesCountToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :responses_count, :integer, default: 0, null: false
  end
end
