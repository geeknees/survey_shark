class AddDefaultValueToInitialQuestion < ActiveRecord::Migration[8.0]
  def change
    default_question = "まず、日常生活で感じている課題や不便なことを3つまで教えてください。どんな小さなことでも構いません。"

    change_column_default :projects, :initial_question, default_question
  end
end
