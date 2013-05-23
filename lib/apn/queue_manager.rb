module APN
  # Enqueues a notification to be sent in the background via the persistent TCP socket, assuming apn_sender is running (or will be soon)
  def self.notify(token, opts = {})
    token = token.to_s.gsub(/\W/, '')
    APN::QueueManager.enqueue(APN::NotificationJob, token, opts)
  end
end
