require 'date'
require 'time'
require 'pp'

require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'json'
require 'coinbase'

disable :logging

#################

configure :development do
    DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/development.db")
    DataMapper::Logger.new($stdout, :debug)
end

configure :production do
    DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_GRAY_URL'])
end

#################

class User
  include DataMapper::Resource

  property :id,               Serial
  property :email,            String
  property :receive_address,  String
  property :password,         String
  property :created_at,       DateTime
end
User.raise_on_save_failure = true  

DataMapper.auto_migrate!

#################

helpers do
end

#################

get '/balance.json' do
  content_type :json
  coinbase = Coinbase::Client.new(ENV['COINBASE_API_KEY'], ENV['COINBASE_API_SECRET'])
  balance = coinbase.balance
  {:amount => balance.to_f}.to_json
end

post '/create_user.json' do
  content_type :json
  
  user_email = params['email']
  hero_email = 'dav+'+(user_email.gsub(/@/,'-at-'))+'@akuaku.org'
  coinbase_password = 'G#$L#$J#@$G#23' #TODO generate random
  
  response = {}
  begin
    hero_user = User.create :email => user_email
    coinbase = Coinbase::Client.new(ENV['COINBASE_API_KEY'], ENV['COINBASE_API_SECRET'])
    cb_response = coinbase.create_user hero_email, coinbase_password
    hero_user.password = coinbase_password
    hero_user.receive_address = cb_response.receive_address
    hero_user.save
    response.merge!({:cb_user => cb_response.user.to_s, :receive_address => hero_user.receive_address, :hero_email => hero_user.email})
  rescue Exception => ex
    response[:error] = ex.to_s
  end
  response.merge(p).to_json
end

get '/users.json' do
  content_type :json
  User.all.to_json
end

not_found do
  return {:error => 'not found: '+request.path}.to_json if request.path =~ /\.json$/
end

error do
  'Something went wrong! We will look into it, and offer our apologies. Please try again later.'
end
