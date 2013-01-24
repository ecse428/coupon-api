require 'sinatra'
require 'json'
require 'pg'

conn = PG.connect( dbname: 'coupon')

get '/' do
  content_type :json
  { :status => 'ok' }.to_json
end

get '/users/:id' do |id|
  content_type :json
  res = conn.exec('SELECT id, username, email
                   FROM users
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'User Not Found' }.to_json
  end

  res[0].to_json
end

get '/coupons' do
  content_type :json
  res = conn.exec('SELECT id, name, description, logo_url
                   FROM coupons')

  coupons = []
  res.each { |row|
    coupons.push(row)
  }

  coupons.to_json
end

get '/coupons/:id' do |id|
  content_type :json
  res = conn.exec('SELECT id, name, description, logo_url
                   FROM coupons
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'Coupon Not Found' }.to_json
  end

  res[0].to_json
end
