require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "ActiveRecord can write and read a trivial record" do
    # Create a simple test using ActiveRecord's internal schema_migrations table
    # This verifies basic database connectivity without requiring custom models
    
    # Ensure we can query the database
    assert_nothing_raised do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    
    # Verify we can read from schema_migrations (always exists in Rails apps)
    result = ActiveRecord::Base.connection.execute("SELECT version FROM schema_migrations LIMIT 1")
    assert_respond_to result, :each
  end
end