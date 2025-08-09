require "test_helper"

class SecurityTokenGeneratorTest < ActiveSupport::TestCase
  test "generate_invite_token produces sufficiently long random string" do
    token = Security::TokenGenerator.generate_invite_token
    assert token.length >= 40 # urlsafe_base64(32) ~ 43 chars
  refute_match(/\s/, token)
  end

  test "generate_anon_hash returns 16 hex chars" do
    h = Security::TokenGenerator.generate_anon_hash
    assert_equal 16, h.length
  assert_match(/\A[0-9a-f]+\z/, h)
  end

  test "tokens are unique" do
    t1 = Security::TokenGenerator.generate_invite_token
    t2 = Security::TokenGenerator.generate_invite_token
    refute_equal t1, t2
  end
end
