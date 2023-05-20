# frozen_string_literal: true

require 'bundler'
Bundler.require :default, (ENV['RACK_ENV'] || :development).to_sym

require_relative './config/zeitwerk'
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

  helpers do
    def logged_in?
      session[:email].present?
    end

    def login_required
      unless logged_in?
        session[:return_to] = request.fullpath
        redirect '/auth/google_oauth2'
      end
    end
  end

  get '/' do
    if logged_in?
      @enterprises = AndroidManagementApi.call('GET /enterprises?projectId={project_id}')['enterprises'] || []
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
      email = auth_hash.dig('info', 'email')
      if auth_hash['uid'].present? && AdminUser.for_user(auth_hash['uid']).present?
        session[:email] = email
        redirect return_url
      else
        puts "auth_hash=#{auth_hash.to_h}"
        halt 403, "Access Forbidden"
      end
    end
  end

  get '/enterprises/:enterprise_name' do
    login_required

    @enterprise = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}")
    @policies = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/policies")['policies'] || []
    @devices = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/devices")['devices'] || []
    erb :'dashboard.html'
  end

  get '/enterprises/:enterprise_name/call' do
    login_required

    erb :'amapi_call.html'
  end

  post '/enterprises/:enterprise_name/call' do
    login_required

    erb :'amapi_call.html'
  end

  get '/enterprises/:enterprise_name/applications' do
    login_required

    payload = AndroidManagementApi.call("POST /enterprises/#{params[:enterprise_name]}/webTokens", payload: {
      parentFrameUrl: request.url,
      enabledFeatures: ["PLAY_SEARCH", "PRIVATE_APPS", "WEB_APPS"],
    })
    @web_token = payload['value']

    erb :'application_select.html'
  end

  get '/enterprises/:enterprise_name/applications/:package_name' do
    login_required

    payload = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/applications/#{params[:package_name]}")
    payload.delete('name')
    @payload = payload

    erb :'application_show.html'
  end

  get '/enterprises/:enterprise_name/policies/new' do
    login_required

    @form_url = "/enterprises/#{params[:enterprise_name]}/policies"
    @identifier = ''
    @payload = {}
    erb :'policy_edit.html'
  end

  get '/enterprises/:enterprise_name/policies/:identifier' do
    login_required

    @form_url = "/enterprises/#{params[:enterprise_name]}/policies"
    @identifier = params[:identifier]
    @payload = AndroidManagementApi.call("GET #{@form_url}/#{@identifier}")
    @payload.delete('name')
    erb :'policy_edit.html'
  end

  post '/enterprises/:enterprise_name/policies' do
    login_required

    AndroidManagementApi.call "PATCH /enterprises/#{params[:enterprise_name]}/policies/#{params[:identifier]}",
      payload: JSON.parse(params[:json])

    redirect "/enterprises/#{params[:enterprise_name]}"
  end

  get '/enterprises/:enterprise_name/policies/:identifier/qr' do
    login_required

    policy_name = "enterprises/#{params[:enterprise_name]}/policies/#{params[:identifier]}"
    payload = AndroidManagementApi.call("GET /#{policy_name}")
    @policy_name = payload['name']

    erb :'qrcode.html'
  end

  get '/enterprises/:enterprise_name/devices/:identifier' do
    login_required

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    @device_show_policy_url = "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}/policy"
    erb :'device_show.html'
  end

  get '/enterprises/:enterprise_name/devices/:identifier/policy' do
    login_required

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    @device_url = "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    @policies = AndroidManagementApi.call("GET /enterprises/#{params[:enterprise_name]}/policies")['policies'] || []

    erb :'device_show_policy.html'
  end

  post '/enterprises/:enterprise_name/devices/:identifier/policy' do
    login_required

    name = "enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
    payload = { 'policyName' => params[:policy_name] }
    AndroidManagementApi.call("PATCH /#{name}?updateMask=policyName", payload: payload)
    redirect "/enterprises/#{params[:enterprise_name]}/devices/#{params[:identifier]}"
  end
end
