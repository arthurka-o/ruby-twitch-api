# frozen_string_literal: true

module Twitch
  # Module for handling Twitch EventSub webhook notifications
  module WebhookHandler
    extend ActiveSupport::Concern

    HMAC_PREFIX = 'sha256='
    HEADER_MESSAGE_ID = 'twitch-eventsub-message-id'
    HEADER_MESSAGE_TIMESTAMP = 'twitch-eventsub-message-timestamp'
    HEADER_MESSAGE_SIGNATURE = 'twitch-eventsub-message-signature'
    HEADER_MESSAGE_TYPE = 'twitch-eventsub-message-type'
    HEADER_SUBSCRIPTION_TYPE = 'twitch-eventsub-subscription-type'

    included do
      before_action :verify_twitch_signature!
      skip_before_action :verify_authenticity_token

      class_attribute :subscription_types, default: []
      class_attribute :twitch_client

      Twitch::WebhookHandler.register_handler(self)
    end

    class_methods do
      def subscribe_to(type, version: '1', **condition)
        subscription_types << {
          type: type,
          version: version.to_s,
          condition: condition
        }
      end

      # rubocop:disable Metrics/MethodLength
      def register_subscriptions(client)
        subscription_types.each do |subscription|
          hash = {
            type: subscription[:type],
            version: subscription[:version],
            condition: subscription[:condition],
            callback_url: webhook_callback_url,
            secret: webhook_secret
          }

          puts hash

          client.create_webhook_subscription(
            type: subscription[:type],
            version: subscription[:version],
            condition: subscription[:condition],
            callback_url: webhook_callback_url,
            secret: webhook_secret
          )
        rescue Twitch::APIError => e
          Rails.logger.error "Failed to register webhook subscription: #{e.message}"
        end
      end
    end

    class << self
      def handlers
        @handlers ||= []
      end

      def register_handler(handler_class)
        handlers << handler_class
        puts "Registered handler: #{handler_class}"
      end

      def setup_client(client)
        puts "Setting up client for #{handlers.count} handlers"
        handlers.each do |handler_class|
          puts "Configuring handler: #{handler_class}"
          handler_class.twitch_client = client
          handler_class.register_subscriptions(client)
        end
      end
    end

    def receive
      case request.headers[HEADER_MESSAGE_TYPE]&.downcase
      when 'webhook_callback_verification'
        handle_verification
      when 'notification'
        handle_notification
      when 'revocation'
        handle_revocation
      else
        head :no_content
      end
    end

    private

    def verify_twitch_signature!
      message = build_hmac_message
      hmac = "#{HMAC_PREFIX}#{generate_hmac(webhook_secret, message)}"
      return if secure_compare(hmac, request.headers[HEADER_MESSAGE_SIGNATURE])

      head :forbidden
    end

    def build_hmac_message
      request.headers[HEADER_MESSAGE_ID] +
        request.headers[HEADER_MESSAGE_TIMESTAMP] +
        request.raw_post
    end

    def generate_hmac(secret, message)
      OpenSSL::HMAC.hexdigest('sha256', secret, message)
    end

    def secure_compare(a, b)
      return false unless b

      ActiveSupport::SecurityUtils.secure_compare(a, b)
    end

    def handle_verification
      render plain: JSON.parse(request.raw_post)['challenge']
    end

    def handle_notification
      event_data = JSON.parse(request.raw_post)
      event_type = request.headers[HEADER_SUBSCRIPTION_TYPE]

      process_event(event_type, event_data)
      head :no_content
    end

    def handle_revocation
      event_data = JSON.parse(request.raw_post)
      process_revocation(event_data)
      head :no_content
    end

    def webhook_secret
      raise NotImplementedError, 'Define webhook_secret in your controller'
    end

    def webhook_callback_url
      raise NotImplementedError, 'Define webhook_callback_url in your controller'
    end

    def process_event(type, data)
      raise NotImplementedError, 'Define process_event in your controller'
    end

    def process_revocation(data)
      raise NotImplementedError, 'Define process_revocation in your controller'
    end
  end
end
