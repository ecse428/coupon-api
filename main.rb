require 'sinatra'
require 'json'
require 'pg'

conn = PG.connect( dbname: 'coupon')

get '/' do
  content_type :json
  { :status => 'ok' }.to_json
end

get '/users/:uid' do |uid|
  content_type :json
  res = conn.exec('SELECT uid, username, email
                   FROM users
                   WHERE uid = $1', [uid])

  if res.num_tuples == 0
    status 404
    return { :error => 'User Not Found' }.to_json
  end

  { :uid => res.getvalue(0, 0),
    :username => res.getvalue(0, 1),
    :email => res.getvalue(0, 2) }.to_json
end

get '/coupons' do
  content_type :json
  {}.to_json
end

get '/coupons/:cid' do |cid|
  content_type :json
  { :cid => cid }.to_json
end
