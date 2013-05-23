module APN
  # End result: single persistent TCP connection to Apple, so they don't ban you for frequently opening and closing connections,
  # which they apparently view as a DOS attack.
  #
  # Accepts <code>:environment</code> (production vs anything else), <code>:cert_pass</code> and <code>:cert_path</code> options on initialization.  If called in a
  # Rails context, will default to RAILS_ENV and RAILS_ROOT/config/certs. :environment will default to development.
  # APN::Sender expects two files to exist in the specified <code>:cert_path</code> directory:
  # <code>apn_production.pem</code> and <code>apn_development.pem</code>.
  #
  # Use the <code>:cert_pass</code> option if your certificates require a password
  #
  # If a socket error is encountered, will teardown the connection and retry again twice before admitting defeat.
  class Sender < ::Resque::Worker
    include APN::Connection::Base
    TIMES_TO_RETRY_SOCKET_ERROR = 2

    # Send a raw string over the socket to Apple's servers (presumably already formatted by APN::Notification)
    def send_to_apple( notification, attempt = 0 )
      if attempt > TIMES_TO_RETRY_SOCKET_ERROR
        log_and_die("Error with connection to #{apn_host} (retried #{TIMES_TO_RETRY_SOCKET_ERROR} times): #{error}")
      end

      self.socket.with do |s|
        s.write( notification.to_s )
      end
    rescue SocketError, Errno::EPIPE => error
      log(:error, "Error with connection to #{apn_host} (attempt #{attempt}): #{error}")

      # Try reestablishing the connection
      teardown_connection
      setup_connection
      send_to_apple(notification, attempt + 1)
    end

    protected

    def apn_host
      @apn_host ||= apn_production? ? "gateway.push.apple.com" : "gateway.sandbox.push.apple.com"
    end

    def apn_port
      2195
    end

  end

end
