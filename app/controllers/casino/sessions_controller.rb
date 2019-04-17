class CASino::SessionsController < CASino::ApplicationController
  include CASino::SessionsHelper
  include CASino::AuthenticationProcessor
  include CASino::TwoFactorAuthenticatorProcessor

  before_action :validate_login_ticket, only: [:create]
  before_action :ensure_service_allowed, only: [:new, :create]
  before_action :load_ticket_granting_ticket_from_parameter, only: [:validate_otp]
  before_action :ensure_signed_in, only: [:index, :destroy]

  def index
    p current_user
    @ticket_granting_tickets = current_user.ticket_granting_tickets.active
    @two_factor_authenticators = current_user.two_factor_authenticators.active
    @login_attempts = current_user.login_attempts.order(created_at: :desc).first(5)
    
  end

  def new
    tgt = params[:is_api] ? current_ticket_granting_ticket_for_api : current_ticket_granting_ticket
    return handle_signed_in(tgt) unless params[:renew] || tgt.nil?
    if params[:gateway] && params[:service].present? && !params[:is_api]
      redirect_to(params[:service]) 
    end
  end

  def create
    p "dasasd"
    validation_result = validate_login_credentials(params[:username], params[:password]])
    p "---validation_result"
    p validation_result
    p !validation_result
    if !validation_result
      log_failed_login params[:username]
       if params[:is_api] 
        p "gggg"
        render json: { status: 'failed', message: I18n.t('login_credential_acceptor.invalid_login_credentials')  }
       else 
        show_login_error I18n.t('login_credential_acceptor.invalid_login_credentials') 
       end
    else
    p "dddd"
      sign_in(validation_result, long_term: params[:rememberMe], 
              credentials_supplied: true, is_api: params[:is_api])
    end
  end

  def destroy
    tickets = current_user.ticket_granting_tickets.where(id: params[:id])
    tickets.first.destroy if tickets.any?
    redirect_to sessions_path
  end

  def destroy_others  
    current_user
      .ticket_granting_tickets
      .where('id != ?', current_ticket_granting_ticket.id)
      .destroy_all if signed_in?
    redirect_to params[:service] || sessions_path
  end

  def logout
    ticket = params[:is_api].present? ? params[:ticket] : cookies[:tgt]
    sign_out(ticket)
    @url = params[:url]
    if params[:is_api]
      render json: { status: 'success', message: I18n.t('logout.logged_out_without_url') },status: :ok
    elsif params[:service].present? && service_allowed?(params[:service])
      redirect_to params[:service], status: :see_other 
    else
      redirect_to login_path(service: params[:destination])
    end
    # redirect_to login_path(service: params[:destination])
  end

  def validate_otp
    validation_result = validate_one_time_password(params[:otp], @ticket_granting_ticket.user.active_two_factor_authenticator)
    return flash.now[:error] = I18n.t('validate_otp.invalid_otp') unless validation_result.success?
    @ticket_granting_ticket.update_attribute(:awaiting_two_factor_authentication, false)
    set_tgt_cookie(@ticket_granting_ticket)
    handle_signed_in(@ticket_granting_ticket)
  end

  private

  def show_login_error_for_api(message)
    render json: { status: 'failed', message: message } and return
  end

  def show_login_error(message)
    flash.now[:error] = message
    render :new, status: :forbidden
  end

  def validate_login_ticket
    if params[:is_api]  
      validate_login_ticket_for_api
    else
      validate_login_ticket_for_form
    end
  end

  def validate_login_ticket_for_api
    params[:lt] = CASino::LoginTicket.create.ticket
    unless CASino::LoginTicket.consume(params[:lt])
      show_login_error_for_api I18n.t('login_credential_acceptor.invalid_login_ticket')
    end
  end

  def validate_login_ticket_for_form
    unless CASino::LoginTicket.consume(params[:lt])
        show_login_error I18n.t('login_credential_acceptor.invalid_login_ticket')
    end
  end

  def ensure_service_allowed
    if params[:is_api]
      ensure_service_allowed_for_api
    else
      ensure_service_allowed_for_form
    end
  end

  def ensure_service_allowed_for_api
    if params[:service].present? && !service_allowed?(params[:service])
      render json: { status: 'failed', message: 'service_not_allowed' } ,status: :forbidden
    end
  end

  def ensure_service_allowed_for_form
    if params[:service].present? && !service_allowed?(params[:service])
      render 'service_not_allowed', status: :forbidden
    end
  end

  def load_ticket_granting_ticket_from_parameter
    @ticket_granting_ticket = find_valid_ticket_granting_ticket(params[:tgt], request.user_agent, ignore_two_factor: true)
    redirect_to login_path if @ticket_granting_ticket.nil?
  end

  def redirect_to_login
    redirect_to login_path(service: params[:service])
    #redirect_to login_path
  end
end
