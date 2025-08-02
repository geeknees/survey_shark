namespace :admin do
  desc "Create or reset admin user"
  task setup: :environment do
    email = ENV['ADMIN_EMAIL'] || begin
      print "Enter admin email: "
      STDIN.gets.chomp
    end
    
    password = ENV['ADMIN_PASSWORD'] || begin
      print "Enter admin password: "
      STDIN.noecho(&:gets).chomp.tap { puts }
    end
    
    admin = Admin.find_or_initialize_by(email_address: email)
    admin.password = password
    admin.password_confirmation = password
    
    if admin.save
      puts "Admin user #{admin.email_address} created/updated successfully!"
    else
      puts "Error creating admin: #{admin.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end