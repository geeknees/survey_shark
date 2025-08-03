class AddInitialQuestionToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :initial_question, :text
  end
end
