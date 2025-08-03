ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

# Load test-specific files
require_relative "../app/services/analysis/fake_llm_client"
require_relative "../app/services/pii/fake_llm_client"
require_relative "../app/services/pii/detector"
require_relative "../app/services/pii/detection_result"
require_relative "../app/services/llm"
require_relative "../app/services/llm/client/openai"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def sign_in_as(admin)
      cookies.encrypted[:session_token] = admin.sessions.create!.token
    end
  end
end
