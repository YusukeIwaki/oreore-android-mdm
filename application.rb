# frozen_string_literal: true

require 'bundler'
Bundler.require :default, (ENV['RACK_ENV'] || :development).to_sym

require_relative './config/activerecord'
require_relative './config/zeitwerk'
require 'sinatra/base'
require 'sinatra/jbuilder'

class Application < Sinatra::Base
  get '/customers' do
    @customers = Customer.all
    jbuilder :"customers/index.json"
  end
  get '/customers/:id' do
    @customer = Customer.find(params[:id])
    jbuilder :"customers/show.json"
  end
  post '/customers' do
    payload = JSON.parse(request.body.read)
    @customer = Customer.new(payload['customer'].slice('name'))
    @customer.save!
    jbuilder :"customers/show.json"
  end
  delete '/customers/:id' do
    @customer = Customer.find(params[:id])
    @customer.destroy!
    jbuilder :"customers/show.json"
  end
end
