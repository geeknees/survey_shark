module Security
  class TokenGenerator
    class << self
      def generate_invite_token
        SecureRandom.urlsafe_base64(32)
      end

      def generate_anon_hash
        Digest::SHA256.hexdigest("#{Time.current.to_f}-#{SecureRandom.hex(16)}")[0..15]
      end
    end
  end
end
