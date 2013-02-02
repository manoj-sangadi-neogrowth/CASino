require 'builder'
require 'casino_core/builder'

class CASinoCore::Builder::TicketValidationResponse < CASinoCore::Builder
  def initialize(success, options)
    @success = success
    @options = options
  end

  def build
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.cas :serviceResponse, 'xmlns:cas' => 'http://www.yale.edu/tp/cas' do |service_response|
      if @success
        ticket = @options[:ticket]
        if ticket.is_a?(CASinoCore::Model::ProxyTicket)
          proxies = []
          _ticket = ticket
          while _ticket.is_a?(CASinoCore::Model::ProxyTicket)
            proxy_granting_ticket = ticket.proxy_granting_ticket
            proxies << proxy_granting_ticket.pgt_url
            _ticket = proxy_granting_ticket.granter
          end
          ticket_granting_ticket = _ticket.ticket_granting_ticket
        else
          ticket_granting_ticket = ticket.ticket_granting_ticket
        end

        build_success_xml(service_response, ticket, ticket_granting_ticket, proxies)
      else
        build_failure_xml(service_response)
      end
    end
    xml.target!
  end

  private
  def serialize_extra_attribute(builder, key, value)
    if value.kind_of?(String) || value.kind_of?(Numeric) || value.kind_of?(Symbol)
      builder.cas key, "#{value}"
    else
      builder.cas key do |container|
        container.cdata! value.to_yaml
      end
    end
  end

  def build_success_xml(service_response, ticket, ticket_granting_ticket, proxies)
    user = ticket_granting_ticket.user
    service_response.cas :authenticationSuccess do |authentication_success|
      authentication_success.cas :user, user.username
      unless user.extra_attributes.blank?
        authentication_success.cas :attributes do |attributes|
          user.extra_attributes.each do |key, value|
            serialize_extra_attribute(attributes, key, value)
          end
        end
      end
      if @options[:proxy_granting_ticket]
        proxy_granting_ticket = @options[:proxy_granting_ticket]
        authentication_success.cas :proxyGrantingTicket, proxy_granting_ticket.iou
      end
      if ticket.is_a?(CASinoCore::Model::ProxyTicket)
        authentication_success.cas :proxies do |proxies_container|
          proxies.each do |proxy|
            proxies_container.cas :proxy, proxy
          end
        end
      end
    end
  end

  def build_failure_xml(service_response)
    service_response.cas :authenticationFailure, @options[:error_message], code: @options[:error_code]
  end
end
