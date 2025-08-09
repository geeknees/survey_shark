require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email uniqueness" do
  User.create!(email_address: "unique_user@example.com", password: "password123")
  u = User.new(email_address: "unique_user@example.com", password: "password123")
  refute u.valid?
  assert_includes u.errors[:email_address], "has already been taken"
  end

  test "requires email and password" do
    u = User.new
    refute u.valid?
  assert_includes u.errors[:email_address], "can't be blank"
  # has_secure_password adds error on password_digest when password missing
  assert_includes u.errors[:password], "can't be blank"
  end
end
