require 'casino/authenticator'

module CASino::AuthenticationProcessor
  extend ActiveSupport::Concern

  def self.validate_login_credentials(username, password)
    authentication_result = nil
    CASino::Authenticators.authenticators.each do |authenticator_name, authenticator|
      begin
        data = authenticator.validate(username, password)
      rescue CASino::Authenticator::AuthenticatorError => e
        Rails.logger.error "Authenticator '#{authenticator_name}' (#{authenticator.class}) raised an error: #{e}"
      end
      if data
        authentication_result = { authenticator: authenticator_name, user_data: data }
        Rails.logger.info("Credentials for username '#{data[:username]}' successfully validated using authenticator '#{authenticator_name}' (#{authenticator.class})")
        break
      end
    end
    authentication_result
  end

  def load_user_data(authenticator_name, username)
    authenticator = authenticators[authenticator_name]
    return nil if authenticator.nil?
    return nil unless authenticator.respond_to?(:load_user_data)
    authenticator.load_user_data(username)
  end
end
