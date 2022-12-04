require 'base64'
require 'googleauth'
require 'json'
require 'relax2/base'
require 'stringio'

class AndroidManagementApi < Relax2::Base
  module Internal
    ACCESS_TOKEN_CACHE = Relax2::FileCache.new('oreoremdm', 'android_management_api_access_token')

    module_function

    # export SERVICE_ACCOUNT_CREDENTIAL_JSON=$(cat ~/Downloads/oreore-mdm-*.json | base64)
    def service_account_string
      @service_account_string ||= Base64.decode64(ENV['SERVICE_ACCOUNT_CREDENTIAL_JSON'])
    end

    def fetch_access_token(service_account_string)
      client = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_string),
        scope: ['https://www.googleapis.com/auth/androidmanagement'],
      )
      client.fetch_access_token!
      client.access_token
    end

    def auth_with_google(request, perform_request)
      raise 'configure is required' unless service_account_string

      cached_access_token = ACCESS_TOKEN_CACHE.load
      access_token = cached_access_token || fetch_access_token(service_account_string)

      service_account_json = JSON.parse(service_account_string)
      request.query_parameters.map! do |name, value|
        [name, value.gsub('{project_id}', service_account_json['project_id'])]
      end
      request.headers << ['Authorization', "Bearer #{access_token}"]
      response = perform_request.call(request)

      if response.status == 401
        if cached_access_token
          ACCESS_TOKEN_CACHE.clear
          cached_access_token = nil

          access_token = fetch_access_token(service_account_string)
          request.headers.reject! { |name, value| name == 'Authorization' }
          request.headers << ['Authorization', "Bearer #{access_token}"]
          response = perform_request.call(request)
        end
      end

      if response.status < 300
        if !cached_access_token
          ACCESS_TOKEN_CACHE.save(access_token)
        end
      end

      response
    end
  end

  # AndroidManagementApi.call "GET /enterprises/#{enterprise_key}/devices"
  #
  # AndroidManagementApi.call "POST /enterprises/#{enterprise_key}/policies/#{policy_key}",
  #   payload: { ... }
  #
  def self.call(url_and_params, payload: nil)
    args = url_and_params.strip.split(" ")

    request =
      if payload
        Relax2::Request.from(args: args, body: payload.to_json)
      else
        Relax2::Request.from(args: args)
      end

    response = super(request)
    JSON.parse(response.body)
  end

  base_url 'https://androidmanagement.googleapis.com/v1'
  interceptor Internal.method(:auth_with_google)
  interceptor :json_request
end
