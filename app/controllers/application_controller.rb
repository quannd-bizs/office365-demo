class ApplicationController < ActionController::Base
    before_action :load_office365_service, except: [:new, :index]
    before_action :find_user
    skip_before_action :verify_authenticity_token
  
    def index
    end
  
    def new
    end
    
    def create
        redirect_to @office365_service.get_login_url sessions_callback_url
    end

    def update
    @token = @user.access_token if @office365_service.renew_token @user
    render :index
    end

    def destroy
    reset_session
    redirect_to @office365_service.get_logout_url root_url
    end

    def callback
    unless @office365_service.store_access_token params
        flash[:error] = "Something went wrong ..."
    end
    session[:email] = @office365_service.email
    redirect_to root_url
    end

    private
    def load_office365_service
    @office365_service = Office365Service.new
    end

    def find_user
    @user = User.find_by email: session[:email]
    end

    def get_login_url callback_url
        "#{Settings.office_365_api.AUTHORIZE_ENDPOINT}?client_id=#{ENV["CLIENT_ID"]}\
          &redirect_uri=#{ERB::Util.url_encode callback_url}\
          &response_mode=form_post&response_type=code+id_token&nonce=#{nonce}"
    end
    
    def store_access_token params
        # authorize code, use this to get access token
        auth_code = params["code"]
        user_info = get_user_info_from_id_token params["id_token"]
        @email = user_info[:email]
        response = request_access_token auth_code, Settings.office_365_api.REPLY_URL
        if response.class.name == Settings.office_365_api.ADAL_SUCCESS
        return create_or_update_user response, user_info[:email], user_info[:name]
        end
        false
    end

    private
    def nonce
    SecureRandom.uuid
    end

    def request_access_token auth_code, reply_url
    auth_context = ADAL::AuthenticationContext.new(
        Settings.office_365_api.CONTEXT_PATH, Settings.office_365_api.TENANT)
    auth_context.acquire_token_with_authorization_code auth_code, reply_url,
        CLIENT_CRED, Settings.office_365_api.GRAPH_RESOURCE
    end

    # get user info code from jwt
    def get_user_info_from_id_token id_token
        token_parts = id_token.split(".")
        encoded_token = token_parts[1]
        leftovers = token_parts[1].length.modulo(4)
        if leftovers == 2
            encoded_token << "=="
        elsif leftovers == 3
            encoded_token << "="
        end
        decoded_token = Base64.urlsafe_decode64(encoded_token)
        jwt = JSON.parse decoded_token
        {email: jwt["unique_name"], name: jwt["name"]}
    end

    def create_or_update_user response, email, name
        params = {access_token: response.access_token, refresh_token: response.refresh_token,
            account_type: :office365, expires_on: response.expires_on, name: name, email: email}
        user = User.find_by email: email
        return user.update_attributes params if user
        user = User.new params
        user.save
    end

    def send_mail params, session, user
        name = session[:name]
        email = session[:email]
        receiver = params[:receiver]
        send_mail_endpoint = URI "#{Settings.office_365_api.GRAPH_RESOURCE}#{SENDMAIL_ENDPOINT}"
        http = Net::HTTP.new send_mail_endpoint.host, send_mail_endpoint.port
        http.use_ssl = true
    
        email_message = "{
        Message: {
            Subject: \'Welcome your polla\',
            Body: {
            ContentType: \'HTML\',
            Content: \'Hello world\'
            },
            ToRecipients: [
            {
                EmailAddress: {
                Address: \'#{receiver}\'
                }
            }
            ]
        },
        SaveToSentItems: true
        }"
    
        response = http.post(
        SENDMAIL_ENDPOINT,
        email_message,
        "Authorization" => "Bearer #{user.access_token}",
        "Content-Type" => Settings.office_365_api.CONTENT_TYPE
        )
        return true if response.code == "202"
        false
    end

    def renew_token user
        auth_context = ADAL::AuthenticationContext.new(
        Settings.office_365_api.CONTEXT_PATH, Settings.office_365_api.TENANT)
        response = auth_context.acquire_token_with_refresh_token user.refresh_token,
        CLIENT_CRED, Settings.office_365_api.GRAPH_RESOURCE
        if response.class.name == Settings.office_365_api.ADAL_SUCCESS
        return user.update_attributes access_token: response.access_token,
            expires_on: response.expires_on, refresh_token: response.refresh_token
        end
        false
    end

    def get_logout_url target_url
        "#{Settings.office_365_api.LOGOUT_ENDPOINT}?post_logout_redirect_uri=#{ERB::Util.url_encode target_url}"
    end
end
