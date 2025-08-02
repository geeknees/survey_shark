require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "email address presence validation" do
    admin = Admin.new(password: "password123")
    assert_not admin.valid?
    assert_includes admin.errors[:email_address], "can't be blank"
  end
  
  test "email address uniqueness validation" do
    Admin.create!(email_address: "admin@example.com", password: "password123")
    
    duplicate_admin = Admin.new(email_address: "admin@example.com", password: "password456")
    assert_not duplicate_admin.valid?
    assert_includes duplicate_admin.errors[:email_address], "has already been taken"
  end
  
  test "email address normalization" do
    admin = Admin.create!(email_address: "  ADMIN@EXAMPLE.COM  ", password: "password123")
    assert_equal "admin@example.com", admin.email_address
  end
end
