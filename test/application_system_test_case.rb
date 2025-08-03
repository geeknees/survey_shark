require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include ActiveJob::TestHelper

  def sign_in_as(admin)
    session = Session.create!(admin: admin, user_agent: "Test", ip_address: "127.0.0.1")
    # For system tests, we need to set the cookie in the browser
    page.driver.browser.manage.add_cookie(
      name: "session_token",
      value: session.token
    )
  end
end
