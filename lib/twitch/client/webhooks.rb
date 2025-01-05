# frozen_string_literal: true

module Twitch
  class Client
    # Module for EventSub webhook functionality
    module Webhooks
      ## https://dev.twitch.tv/docs/api/reference#create-eventsub-subscription
      def create_webhook_subscription(type:, condition:, callback_url:, secret:, version: '1')
        response = initialize_response nil, post('eventsub/subscriptions', {
          type: type,
          version: version,
          condition: condition,
          transport: {
            method: 'webhook',
            callback: callback_url,
            secret: secret
          }
        })

        puts response.data
        puts response.raw
      end

      ## https://dev.twitch.tv/docs/api/reference#get-eventsub-subscriptions
      def get_webhook_subscriptions(status: nil, type: nil)
        params = {}
        params[:status] = status if status
        params[:type] = type if type

        initialize_response nil, get('eventsub/subscriptions', params)
      end

      ## https://dev.twitch.tv/docs/api/reference#delete-eventsub-subscription
      def delete_webhook_subscription(id:)
        initialize_response nil, delete('eventsub/subscriptions', { id: id })
      end
    end

    include Webhooks
  end
end
