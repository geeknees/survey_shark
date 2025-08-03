require "test_helper"

class AdminsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = admins(:one)
    @admin.update!(password: "password123", password_confirmation: "password123")

    # Sign in the admin
    post session_url, params: {
      email_address: @admin.email_address,
      password: "password123"
    }
  end

  test "should get edit_password" do
    get edit_password_admin_url(@admin)
    assert_response :success
    assert_select "h1", "Change Password"
    assert_select "form"
    assert_select "input[type='password'][name='current_password']"
    assert_select "input[type='password'][name='admin[password]']"
    assert_select "input[type='password'][name='admin[password_confirmation]']"
  end

  test "should update password with correct current password" do
    patch update_password_admin_url(@admin), params: {
      current_password: "password123",
      admin: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to root_path
    assert_equal "Password was successfully updated.", flash[:notice]

    # Verify the password was actually changed
    @admin.reload
    assert @admin.authenticate("newpassword123")
    assert_not @admin.authenticate("password123")
  end

  test "should not update password with incorrect current password" do
    patch update_password_admin_url(@admin), params: {
      current_password: "wrongpassword",
      admin: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_content
    assert_equal "Current password is incorrect.", flash[:alert]

    # Verify the password was not changed
    @admin.reload
    assert @admin.authenticate("password123")
    assert_not @admin.authenticate("newpassword123")
  end

  test "should not update password when confirmation does not match" do
    patch update_password_admin_url(@admin), params: {
      current_password: "password123",
      admin: {
        password: "newpassword123",
        password_confirmation: "differentpassword"
      }
    }

    assert_response :unprocessable_content
    assert_equal "Password confirmation doesn't match or password is too short.", flash[:alert]

    # Verify the password was not changed
    @admin.reload
    assert @admin.authenticate("password123")
    assert_not @admin.authenticate("newpassword123")
  end

  test "should not update password when new password is too short" do
    patch update_password_admin_url(@admin), params: {
      current_password: "password123",
      admin: {
        password: "short",
        password_confirmation: "short"
      }
    }

    assert_response :unprocessable_content
    assert_equal "Password confirmation doesn't match or password is too short.", flash[:alert]

    # Verify the password was not changed
    @admin.reload
    assert @admin.authenticate("password123")
    assert_not @admin.authenticate("short")
  end

  test "should redirect to login if not authenticated" do
    # Sign out
    delete session_url

    get edit_password_admin_url(@admin)
    
    # Should redirect to login page
    assert_redirected_to new_session_path
  end
end
