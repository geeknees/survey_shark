module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.admin
        else
          # Allow unauthenticated connections for public conversation pages
          self.current_user = nil
        end
      end
  end
end
