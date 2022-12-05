# frozen_string_literal: true

require 'bundler'
Bundler.require :default, (ENV['RACK_ENV'] || :development).to_sym

require_relative './config/activerecord'
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
      session[:google_account_id].present?
    end

    def login_required
      unless logged_in?
        redirect '/auth/google_oauth2'
      end
    end

    def current_google_account
      @current_google_account ||= GoogleAccount.find(session[:google_account_id])
    end

    def current_enterprise
      current_enterprise ||= current_google_account.enterprises.find_by(name: params[:enterprise_name])
    end

    def enterprise_required
      unless current_enterprise
        redirect '/'
      end
    end
  end

  get '/' do
    if logged_in?
      if current_google_account.enterprises.size == 1
        enterprise = current_google_account.enterprises.last
        redirect "/enterprises/#{enterprise.name}"
      else
        @enterprises = current_google_account.enterprises
        erb :'select_enterprise.html'
      end
    else
      erb :'login.html'
    end
  end

  get '/auth/google_oauth2/callback' do
    auth_hash = env["omniauth.auth"]
    if auth_hash.dig('info', 'email_verified')
      google_account = GoogleAccount.find_or_initialize_by(
        uid: auth_hash['uid']
      )
      google_account.update!(
        email: auth_hash.dig('info', 'email')
      )
      session[:google_account_id] = google_account.id
      redirect '/'
    end
  end

  get '/enterprises/:enterprise_name' do
    login_required
    enterprise_required

    erb :'dashboard.html'
  end

  get '/enterprises/:enterprise_name/policies/new' do
    login_required
    enterprise_required

    @form_url = "/enterprises/#{current_enterprise.name}/policies"
    @identifier = ''
    @payload = ''
    erb :'policy_edit.html'
  end

  get '/enterprises/:enterprise_name/policies/:identifier' do
    login_required
    enterprise_required

    @form_url = "/enterprises/#{current_enterprise.name}/policies"
    @identifier = params[:identifier]
    payload = AndroidManagementApi.call("GET #{@form_url}/#{@identifier}")
    payload.delete('name')
    @payload = JSON.pretty_generate(payload)
    erb :'policy_edit.html'
  end

  post '/enterprises/:enterprise_name/policies' do
    login_required
    enterprise_required

    AndroidManagementApi.call "PATCH /enterprises/#{current_enterprise.name}/policies/#{params[:identifier]}",
      payload: JSON.parse(params[:json])

    redirect "/enterprises/#{current_enterprise.name}"
  end

  get '/enterprises/:enterprise_name/policies/:identifier/qr' do
    login_required
    enterprise_required

    policy_name = "enterprises/#{current_enterprise.name}/policies/#{params[:identifier]}"
    payload = AndroidManagementApi.call("GET /#{policy_name}")
    @policy_name = payload['name']
    erb :'qrcode.html'
  end

  get '/enterprises/:enterprise_name/devices/:identifier' do
    login_required
    enterprise_required

    name = "enterprises/#{current_enterprise.name}/devices/#{params[:identifier]}"
    @device = AndroidManagementApi.call("GET /#{name}")
    erb :'device_show.html'
  end
end
