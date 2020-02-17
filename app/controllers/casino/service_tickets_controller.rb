class CASino::ServiceTicketsController < CASino::ApplicationController
  include CASino::ControllerConcern::TicketValidator

  before_action :load_service_ticket
  before_action :ensure_service_ticket_parameters_present, only: [:service_validate,:generate_service_ticket]
  before_action :ensure_ticket_parameters_present, only: [:validate_tgt]

  def validate
    if ticket_valid_for_service?(@service_ticket, params[:service], renew: params[:renew])
      @username = @service_ticket.ticket_granting_ticket.user.username
    end
    render :validate, formats: [:text]
  end

  def service_validate
    validate_ticket(@service_ticket)
  end

  def generate_service_ticket
    tgt= CASino::TicketGrantingTicket.find_by!(ticket: params[:ticket])
    st = acquire_service_ticket(tgt, params[:service], {})
    render json: { status: 'success', message: st&.ticket },status: :ok
  rescue ActiveRecord::RecordNotFound 
    render json: { status: 'failed', message: I18n.t('tickets.service_invalid')}, status: :bad_request
  end

  def validate_tgt
    tgt= CASino::TicketGrantingTicket.find_by!(ticket: params[:ticket])
    render json: { status: 'success', message: I18n.t('tickets.tgt_valid') },status: :ok
  rescue ActiveRecord::RecordNotFound 
    render json: { status: 'failed', message: I18n.t('tickets.tgt_invalid') }, status: :bad_request
  end

  private
  def load_service_ticket
    @service_ticket = CASino::ServiceTicket.where(ticket: params[:ticket]).first if params[:service].present?
  end
end
