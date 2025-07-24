# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Stripe Webhooks', type: :request do
  path '/api/v1/stripe_payments_webhook/handle' do
    post('Handles incoming Stripe events') do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      description 'Receives and verifies asynchronous events from Stripe to update payment statuses.'
      parameter name: 'Stripe-Signature',
                in: :header,
                type: :string,
                required: true,
                description: 'Signature sent by Stripe to verify the event authenticity.'

      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :string, example: 'evt_12345' },
          object: { type: :string, example: 'event' },
          type: { type: :string, example: 'charge.succeeded' },
          api_version: { type: :string, example: '2020-08-27' },
          data: {
            type: :object,
            properties: {
              object: {
                type: :object,
                properties: {
                  id: { type: :string, example: 'ch_67890' },
                  amount: { type: :integer, example: 1000 },
                  status: { type: :string, example: 'succeeded' }
                }
              }
            }
          }
        },
        required: %w[id type data]
      }, description: 'The Stripe event payload.'

      response('200', 'webhook acknowledged') do
        schema type: :object, properties: {
          message: { type: :string, example: 'Webhook handled successfully' }
        }
        let(:'Stripe-Signature') { 't=1492774577,v1=...,v0=...' }
        let(:event) { { id: 'evt_123', type: 'charge.succeeded', data: { object: {} } } }
        run_test!
      end

      response('400', 'bad request (e.g., invalid signature)') do
        schema type: :object, properties: {
          errors: { type: :array, items: { type: :string }, example: ['Signature verification failed'] }
        }
        let(:'Stripe-Signature') { 'invalid_signature' }
        let(:event) { { id: 'evt_123', type: 'charge.succeeded', data: { object: {} } } }
        run_test!
      end
    end
  end
end
