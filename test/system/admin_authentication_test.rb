require "application_system_test_case"

class AdminAuthenticationTest < ApplicationSystemTestCase
  test "visiting projects redirects to sign in when logged out" do
    visit projects_path
    
    assert_current_path new_session_path
    assert_text "Sign in"
  end
  
  test "admin can sign in and reach projects index" do
    admin = Admin.create!(
      email_address: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    visit new_session_path
    
    fill_in "email_address", with: "admin@example.com"
    fill_in "password", with: "password123"
    click_button "Sign in"
    
    assert_current_path projects_path
  end
end