require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include ActiveJob::TestHelper

  def setup
    super
    # Disable WebMock for system tests to avoid conflicts with Selenium
    if defined?(WebMock)
      WebMock.disable!
    end
  end

  def sign_in_as(admin)
    visit new_session_path
    fill_in "email_address", with: admin.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"
  end

  # Helper method for system tests that need WebMock
  def enable_webmock_with_system_test_support
    require "webmock/minitest"
    WebMock.enable!
    # Allow local connections for Selenium WebDriver
    # Selenium typically uses random ports in the 9000-10000 range
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        "127.0.0.1",
        "localhost",
        /127\.0\.0\.1:\d+/,
        /localhost:\d+/
      ]
    )
  end

  def disable_webmock
    WebMock.disable! if defined?(WebMock)
  end
end
