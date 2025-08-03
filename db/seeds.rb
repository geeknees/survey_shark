# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create sample admin if none exists
if Admin.count == 0
  Admin.create!(
    email_address: "admin@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  puts "Created sample admin: admin@example.com / password123"
end

# Create sample project with limit 10
sample_project = Project.find_or_create_by!(name: "サンプルプロジェクト") do |project|
  project.goal = "ユーザーの日常的な課題や不便を理解し、改善点を見つけることを目的としています。"
  project.must_ask = [
    "具体的な場面や状況",
    "感じた不便さの程度"
  ]
  project.never_ask = [
    "個人的な収入について",
    "家族構成の詳細"
  ]
  project.tone = "polite_soft"
  project.limits = {
    "max_turns" => 12,
    "max_deep" => 2
  }
  project.status = "active"
  project.max_responses = 10
  project.responses_count = 0
end

# Create invite link for sample project
if sample_project.invite_links.empty?
  sample_project.invite_links.create!(
    token: SecureRandom.urlsafe_base64(32),
    reusable: true
  )
end

puts "Sample project created: #{sample_project.name}"
puts "Invite URL: /i/#{sample_project.invite_links.first.token}"
puts "Max responses: #{sample_project.max_responses}"

# Create some sample conversations and insights for demonstration
if Rails.env.development? && sample_project.conversations.empty?
  # Create sample participants and conversations
  3.times do |i|
    participant = sample_project.participants.create!(
      anon_hash: Digest::SHA256.hexdigest("sample-#{i}-#{Time.current.to_f}"),
      age: [25, 35, 45][i],
      custom_attributes: {}
    )
    
    conversation = sample_project.conversations.create!(
      participant: participant,
      state: "done",
      started_at: (i + 1).hours.ago,
      finished_at: i.hours.ago,
      ip: "127.0.0.1",
      user_agent: "Sample Browser"
    )
    
    # Add sample messages
    conversation.messages.create!(role: 0, content: "コンピューターの動作が遅くて困っています")
    conversation.messages.create!(role: 1, content: "詳しく教えてください")
    conversation.messages.create!(role: 0, content: "特に朝の起動時に時間がかかります")
    conversation.messages.create!(role: 1, content: "他にも困っていることはありますか？")
    conversation.messages.create!(role: 0, content: "ソフトウェアの操作が複雑で使いにくいです")
  end
  
  # Create sample insight cards
  sample_project.insight_cards.create!(
    theme: "システムパフォーマンス",
    jtbds: "スムーズにコンピューター作業を行いたい",
    severity: 4,
    freq_conversations: 2,
    freq_messages: 4,
    confidence_label: "H",
    evidence: ["コンピューターの動作が遅い", "起動時に時間がかかる"]
  )
  
  sample_project.insight_cards.create!(
    theme: "ユーザビリティ",
    jtbds: "直感的にソフトウェアを使いたい",
    severity: 3,
    freq_conversations: 1,
    freq_messages: 2,
    confidence_label: "M",
    evidence: ["操作が複雑", "使いにくい"]
  )
  
  puts "Created sample conversations and insights for development"
end
