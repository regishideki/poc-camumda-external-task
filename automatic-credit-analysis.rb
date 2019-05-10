require 'json'
require 'uri'
require 'net/http'

class CamundaExternalTaskScript
  attr_reader :request

  def run
    loop do
      url = URI("https://auth-staging.creditas.com.br/api/internal_clients/tokens")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request["accept-version"] = 'v1'
      request["content-type"] = 'application/json'
      request["cache-control"] = 'no-cache'
      request.body = JSON.dump(
        "grant_type": "password",
        "username": "core",
        "password": ""
      )

      response = http.request(request)
      token = JSON.parse(response.read_body)['access_token']

      url = URI("https://camunda.journey.stg.creditas.io/engine-rest/external-task/fetchAndLock")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request["authorization"] = "Bearer #{token}"
      request["content-type"] = 'application/json'
      request["cache-control"] = 'no-cache'
      request.body = JSON.dump(
        "workerId": "my-fancy-id",
        "maxTasks": 1,
        "usePriority": true,
        "topics": [
          {
            "topicName": "AutomaticCreditAnalysis",
            "lockDuration": 10000
          }
        ]
      )

      response = http.request(request)
      decoded_response = JSON.parse(response.read_body)

      if decoded_response.any?
        puts decoded_response
        decoded_task = decoded_response.first

        url = URI("https://camunda.journey.stg.creditas.io/engine-rest/external-task/#{decoded_task['id']}/complete")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request["authorization"] = "Bearer #{token}"
        request["content-type"] = 'application/json'
        request["cache-control"] = 'no-cache'
        request.body = JSON.dump(
          "workerId": "my-fancy-id",
          "variables": {
            'analysisResult': {
              'value': creditAnalysisResult(decoded_task['businessKey'].to_i)
            }
          }
        )

        response = http.request(request)
        puts response.code
        puts response.read_body
      else
        print '.'
      end

      sleep(2)
    end
  end

  def creditAnalysisResult(business_key)
    {
      0 => 'rejected',
      1 => 'approved',
      2 => 'grey'
    }.fetch(business_key % 3)
  end
end

CamundaExternalTaskScript.new.run
