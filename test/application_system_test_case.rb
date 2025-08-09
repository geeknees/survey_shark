require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include ActiveJob::TestHelper

  def setup
    super
    # Set OpenAI API key for tests
    ENV["OPENAI_API_KEY"] = "test-api-key"
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

    # Debug: ensure we're not on the login page anymore
    assert_no_current_path new_session_path, wait: 5
  end

  # Polls the database for a Message with exact content (plain string match).
  # Avoids brittle Capybara text matching issues with overflow containers / styling.
  def wait_for_message(content, timeout: 5)
    start = Time.now
    loop do
      return true if Message.where(content: content).exists?
      break if Time.now - start > timeout
      sleep 0.1
    end
    flunk "Message with content '#{content}' not found within #{timeout}s"
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
