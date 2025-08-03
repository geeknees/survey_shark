ENV["RAILS_ENV"] ||= "test"
# Set a fake OpenAI API key for tests to avoid API key errors
ENV["OPENAI_API_KEY"] ||= "test-api-key"
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
      if respond_to?(:post) # Integration test
        post session_path, params: {
          email_address: admin.email_address,
          password: "password123" # This matches the password in fixtures
        }
      else
        # For unit tests, set up session directly
        @current_session = admin.sessions.create!
        Current.session = @current_session
      end
    end

    def sign_out
      if respond_to?(:delete) # Integration test
        delete session_path
      else
        Current.session = nil
        @current_session = nil
      end
    end
  end
end
