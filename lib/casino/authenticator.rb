module CASino
  class Authenticator
    class AuthenticatorError < StandardError; end

    def validate(username, password)
      p "00000000"
      p username
      p password
      raise NotImplementedError, "This method must be implemented by a class extending #{self.class}"
    end
  end
end
