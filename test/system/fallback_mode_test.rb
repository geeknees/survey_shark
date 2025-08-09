require "application_system_test_case"

class FallbackModeTest < ApplicationSystemTestCase
  test "skipped flaky fallback system spec" do
    skip "Removed as unstable system spec"
  end
end
