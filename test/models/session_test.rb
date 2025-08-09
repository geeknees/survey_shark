require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    unique_email = "admin_#{SecureRandom.hex(4)}@example.com"
    @admin = Admin.create!(email_address: unique_email, password: "password123")
  end

  test "belongs to admin" do
    session = Session.create!(admin: @admin)
    assert_equal @admin, session.admin
  end
end
