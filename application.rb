# frozen_string_literal: true

require 'bundler'
Bundler.require :default, (ENV['RACK_ENV'] || :development).to_sym

require_relative './config/zeitwerk'
require 'rack/contrib'
require 'sinatra/base'
require 'sinatra/jbuilder'

require 'omniauth'
require 'omniauth-google-oauth2'
OmniAuth.config.allowed_request_methods = %i[get]

class Application < Sinatra::Base
  enable :sessions
  use OmniAuth::Builder do
    provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET']
  end
  use Rack::JSONBodyParser, verbs: ['POST', 'PATCH', 'PUT']

  helpers do
    def logged_in?
      session[:uid].present?
    end

    def login_required
      unless logged_in?
        session[:return_to] = request.fullpath
        redirect '/auth/google_oauth2'
      end
    end

    def current_user_accessible?(param_enterprise_name)
      AdminUser.contains?(session[:uid], param_enterprise_name)
    end

    def check_enterprise_name_param
      unless current_user_accessible?(params[:enterprise_name])
        halt 403, "No permission to access #{params[:enterprise_name]}"
      end
    end

    def api_authorized?
      request.env['HTTP_AUTHORIZATION'] == "Bearer #{ENV['OREORE_API_KEY']}"
    end

    def api_authorization_required
      halt 403, "Access Forbidden" unless api_authorized?
    end
  end

  get '/' do
    if logged_in?
      @enterprises = AndroidManagementApi.call('GET /enterprises?projectId={project_id}')['enterprises'] || []
      @enterprises.select! { |enterprise| current_user_accessible?(enterprise['name'].split('/').last) }
      erb :'select_enterprise.html'
    else
      erb :'login.html'
    end
  end

  get '/auth/google_oauth2/callback' do
    url = session.delete(:return_to)
    return_url =
      if url.blank? || url.include?('/auth/')
        '/'
      else
        url
      end


    auth_hash = env["omniauth.auth"]
    if auth_hash.dig('info', 'email_verified')
      uid = auth_hash['uid']
      if uid.present? && AdminUser.for_user(uid).present?
        session[:uid] = uid
        redirect return_url
      else
        puts "auth_hash=#{auth_hash.to_h}"
        halt 403, "Access Forbidden"
      end
    end
  end

  get '/enterprises/:enterprise_name' do
    login_required
    check_enterprise_name_param

    @enterprise = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}")
    @policies = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/policies?pageSize=100")['policies'] || []
    @devices = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/devices?pageSize=100")['devices'] || []
    erb :'dashboard.html'
  end

  get '/enterprises/:enterprise_name/call' do
    login_required
    check_enterprise_name_param

    erb :'amapi_call.html'
  end

  post '/enterprises/:enterprise_name/call' do
    login_required

    erb :'amapi_call.html'
  end

  get '/enterprises/:enterprise_name/applications' do
    login_required
    check_enterprise_name_param

    payload = AndroidManagementApi.call("POST /enterprises/#{params[:enterprise_name]}/webTokens", payload: {
      parentFrameUrl: request.url,
      enabledFeatures: ["PLAY_SEARCH", "PRIVATE_APPS", "WEB_APPS"],
    })
    @web_token = payload['value']

    erb :'application_select.html'
  end

  get '/enterprises/:enterprise_name/applications/:package_name' do
    login_required
    check_enterprise_name_param

    payload = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/applications/#{params[:package_name]}")
    payload.delete('name')
    @payload = payload

    erb :'application_show.html'
  end

  get '/enterprises/:enterprise_name/policies/new' do
    login_required
    check_enterprise_name_param

    @form_url = "/enterprises/#{params[:enterprise_name]}/policies"
    @identifier = ''
    @payload = {}
    erb :'policy_edit.html'
  end

  get '/enterprises/:enterprise_name/policies/:identifier' do
    login_required
    check_enterprise_name_param

    @form_url = "/enterprises/#{params[:enterprise_name]}/policies"
    @identifier = params[:identifier]
    @payload = AndroidManagementApi.call("GET #{@form_url}/#{@identifier}")
    @payload.delete('name')
    erb :'policy_edit.html'
  end

  post '/enterprises/:enterprise_name/policies' do
    login_required
    check_enterprise_name_param

    AndroidManagementApi.call "PATCH /enterprises/#{params[:enterprise_name]}/policies/#{params[:identifier]}",
      payload: JSON.parse(params[:json])

    redirect "/enterprises/#{params[:enterprise_name]}"
  end

  get '/enterprises/:enterprise_name/policies/:identifier/qr' do
    login_required
    check_enterprise_name_param

    policy_name = "enterprises/#{params[:enterprise_name]}/policies/#{params[:identifier]}"
    payload = AndroidManagementApi.call("GET /#{policy_name}")
    @policy_name = payload['name']

    erb :'qrcode.html'
  end

  get '/enterprises/:enterprise_name/devices/:identifier' do
    login_required
    check_enterprise_name_param

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    @device_show_policy_url = "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}/policy"
    erb :'device_show.html'
  end

  get '/enterprises/:enterprise_name/devices/:identifier/policy' do
    login_required
    check_enterprise_name_param

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    @device_url = "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @policies = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/policies")['policies'] || []

    erb :'device_show_policy.html'
  end

  post '/enterprises/:enterprise_name/devices/:identifier/policy' do
    login_required
    check_enterprise_name_param

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    payload = { 'policyName' => params[:policy_name] }
    AndroidManagementApi.call("PATCH /#{name}?updateMask=policyName", payload: payload)
    redirect "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
  end

  post '/pubsub' do
    payload = JSON.parse(request.body.read)
    data_b64 = payload['message']&.delete('data')
    data_str = Base64.decode64(data_b64)
    data = JSON.parse(data_str) rescue data_str

    puts({
      metadata: payload,
      data: data,
    })
  rescue => err
    puts "ERROR: #{err}"
  end

  get '/api/enterprises/:enterprise_name/devices/:identifier/policy' do
    api_authorization_required

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    @policies = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/policies")['policies'] || []

    jbuilder :'device_show_policy.json'
  end

  patch '/api/enterprises/:enterprise_name/devices/:identifier/policy' do
    api_authorization_required
    policy_name = params.dig(:policy, :name)
    unless policy_name
      halt 400, "policy.name is required"
    end

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    payload = { 'policyName' => policy_name }
    AndroidManagementApi.call("PATCH /#{name}?updateMask=policyName", payload: payload)
    @device = AndroidManagementApi.call("GET /#{name}")

    jbuilder :'device_show_policy.json'
  end
end
