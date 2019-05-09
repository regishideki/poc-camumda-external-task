require 'json'
require 'typhoeus'

module Infra
  class HttpRequest
    def initialize(base_url:, http_requester: Typhoeus::Request, timeout: 3000)
      @base_url = base_url
      @http_requester = http_requester
      @timeout = timeout
    end

    def post(path:, params: nil, body: "", headers: {})
      handle_response do
        @http_requester.new(
          "#{@base_url}/#{path}",
          method: :post,
          params: params,
          body: body,
          cache_ttl: 500,
          connecttimeout_ms: @timeout,
          timeout_ms: @timeout,
          headers: headers
        )
      end
    end

    private
    def handle_response
      request = yield

      request.on_complete do |response|
        return response if response.success?

        fail StandardError
      end

      request.run
    end
  end
end

class CamundaExternalTaskScript
  attr_reader :request

  def initialize
    # falta autenticar :(
    @request = Infra::HttpRequest.new(base_url: 'http://localhost:8080/engine-rest/external-task')
  end

  def run
    loop do
      response = fetch_and_lock(fetch_body(external_tasks_topics))
      decoded_response = JSON.parse(response.response_body)

      if decoded_response.any?
        puts decoded_response
        decoded_task = decoded_response.first

        perform_credit_analysis(decoded_task)

        puts response.response_code
      else
        print '.'
      end

      sleep(2)
    end
  end

  def perform_credit_analysis(decoded_task)
    complete_task(decoded_task, {
      "creditAnalysisResult": {"value": creditAnalysisResult }
    })
  end

  def creditAnalysisResult
    # por enquanto, está aleatório, mas podemos responder de acordo com businessKey para ficar mais determinístico
    ['R', 'A', 'G'].sample
  end

  def complete_task(decoded_task, variables)
    request.post(
      path: "#{decoded_task["id"]}/complete",
      body: JSON.dump(complete_body(variables)),
      headers: {'Content-Type' => 'application/json'}
    )
  end

  def fetch_and_lock(body)
    request.post(
      path: 'fetchAndLock',
      body: JSON.dump(body),
      headers: {'Content-Type' => 'application/json'}
    )
  end

  def complete_body(variables)
    {
      "workerId": "my-fancy-id",
      "variables":
      {
        #"approvalTeam": {"value": 'formalization'},
      }.merge(variables)
    }
  end

  def fetch_body(topics)
    {
      "workerId": "my-fancy-id",
      "maxTasks": 1,
      "usePriority": true,
      "topics": topics
    }
  end

  def external_tasks_topics
    [{
      "topicName": 'AutomaticCreditAnalysis',
      "lockDuration": 10000,
      "variables": []
    }]
  end
end

CamundaExternalTaskScript.new.run
