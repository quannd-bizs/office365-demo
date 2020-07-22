class Office365Service
    attr_accessor :email
  
    SENDMAIL_ENDPOINT = "/v1.0/me/microsoft.graph.sendmail"
    CLIENT_CRED = ADAL::ClientCredential.new(
      ENV["CLIENT_ID"], ENV["CLIENT_SECRET"])
  
    def initialize
    end
  end
