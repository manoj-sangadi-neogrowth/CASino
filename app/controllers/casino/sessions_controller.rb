class CASino::SessionsController < CASino::ApplicationController
  include CASino::SessionsHelper
  include CASino::AuthenticationProcessor
  include CASino::TwoFactorAuthenticatorProcessor

  before_action :validate_login_ticket, only: [:create]
  before_action :ensure_service_allowed, only: [:new, :create]
  before_action :load_ticket_granting_ticket_from_parameter, only: [:validate_otp]
  before_action :ensure_signed_in, only: [:index, :destroy]
  @@is_logout=false
  def index
    @ticket_granting_tickets = current_user.ticket_granting_tickets.active
    @two_factor_authenticators = current_user.two_factor_authenticators.active
    @login_attempts = current_user.login_attempts.order(created_at: :desc).first(5)
  end

  def new
    p "in new"
    p @@is_logout
    p params.merge!({logout: @@is_logout})
    p params
    tgt = current_ticket_granting_ticket
    return handle_signed_in(tgt) unless params[:renew] || tgt.nil?
    if params[:gateway] && params[:service].present?
      p "iam in new "
      @@is_logout=false
      redirect_to(params[:service]) 
    end
  end

  def custom_login
  end

  def create
    @@is_logout=false;
    validation_result = validate_login_credentials(params[:username], params[:password])
    if !validation_result
      log_failed_login params[:username]
      show_login_error I18n.t('login_credential_acceptor.invalid_login_credentials')
    else
      sign_in(validation_result, long_term: params[:rememberMe], credentials_supplied: true)
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
    p "in logout"
    sign_out
    p "999999999"
    @url = params[:url]
    # p params[:service]
    # p service_allowed?(params[:destination])
    # p params.merge!({logout: true})
    # p "params-->>>"
    # p params
    # params[:service] = "http://localhost:3001"
    # if params[:service].present? && service_allowed?(params[:service])
    if params[:destination].present? && service_allowed?(params[:destination])
      p "in if condition"
      @@is_logout=true;
      redirect_to params[:destination], status: :see_other 
    else
      p params
      @@is_logout=true;
      redirect_to login_path(service: params[:destination])
    end
    p "here"
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

  # def show_login_error_for_api(message)
  #   flash.now[:error] = message
  #   return :new, status: :forbidden
  # end

  def show_login_error(message)
    flash.now[:error] = message
    render :new, status: :forbidden
  end

  def validate_login_ticket
    unless CASino::LoginTicket.consume(params[:lt])
      show_login_error I18n.t('login_credential_acceptor.invalid_login_ticket')
    end
  end

  def ensure_service_allowed
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
