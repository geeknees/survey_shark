class SetDefaultInitialQuestionForExistingProjects < ActiveRecord::Migration[8.0]
  def up
    default_question = "まず、日常生活で感じている課題や不便なことを3つまで教えてください。どんな小さなことでも構いません。"

    Project.where(initial_question: [ nil, "" ]).update_all(initial_question: default_question)
  end

  def down
    # No rollback needed since we're only setting values for existing records
  end
end
