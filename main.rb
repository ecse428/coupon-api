require 'sinatra'
require 'json'
require 'pg'
require 'bcrypt'

SECRET = 'S3KR3T-K3Y'

set :public_folder, '../coupon-client'

get '/' do
  redirect '/index.html'
end

def authenticate?
  if request.cookies['key'].nil? || request.cookies['user_key'].nil?
    status 403
    response.write({ :error => '"user_key" and "key" Cookie Required' }.to_json)
    response.close()
    return false
  end

  auth = BCrypt::Password.new(request.cookies['key'])
  if auth != (request.cookies['user_key'] + SECRET)
    status 403
    response.write({ :error => 'Invalid Key' }.to_json)
    response.close()
    return false
  end

  split = request.cookies['user_key'].split(":")
  @user_id = split[0]
  @username = split[1]

  return true
end

before do
  content_type :json

  @conn = PG.connect(:dbname => 'coupon')
  @data = JSON.parse(request.body.read) rescue {}
end

get '/api' do
  { :status => 'OK' }.to_json
end

post '/api/login' do
  if @data['username'].nil? && @data['email'].nil?
    status 400
    return { :error => 'Email or Username Required' }.to_json
  end

  if @data['password'].nil?
    status 400
    return { :error => 'Password Required' }.to_json
  end

  res = @conn.exec('SELECT id, username, password, suspended
                   FROM users
                   WHERE username = $1
                   OR email = $2', [@data['username'], @data['email']])

  if res.num_tuples == 0
    status 404
    return { :error => 'User Not Found' }.to_json
  end

  password = BCrypt::Password.new(res[0]['password'])
  
  if password != @data['password']
    status 403
    return { :error => 'Password Does Not Match' }.to_json
  end

  if res[0]['suspended'] = true
	status 403
	return { :error => 'User suspended'}.to_json
  end

  user_key = res[0]['id'] + ':' + res[0]['username']
  key = BCrypt::Password.create(user_key + SECRET)
  { :id => res[0]['id'],
    :username => res[0]['username'],
    :user_key => user_key,
    :key => key }.to_json
end

post '/api/users' do
  if @data['username'].nil? || @data['email'].nil? || @data['password'].nil?
    status 400
    return { :error => 'Incomplete POST Data' }.to_json
  end

  if @data['password'].length < 8
    status 400
    return { :error => 'Password Length < 8' }.to_json
  end

  res = @conn.exec('SELECT id
                    FROM users
                    WHERE username = $1
                    OR email = $2', [@data['username'], @data['email']])

  if res.num_tuples != 0
    status 400
    return { :error => 'Username/Email Already Taken' }.to_json
  end
  
  hash = BCrypt::Password.create(@data['password'])
  @conn.exec('INSERT INTO users (username, email, password, firstname, lastname, address, phonenumber,suspended,accounttype)
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
              [@data['username'], @data['email'], hash, @data['firstname'], @data['lastname'], @data['address'], @data['phonenumber'], false, @data['accounttype']])

  status 201
  { :status => 'CREATED' }.to_json
end

get '/api/users/:id' do |id|
  return if authenticate? == false

  res = @conn.exec('SELECT id, username, email, phonenumber, firstname, lastname, address, accounttype
                   FROM users
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'User Not Found' }.to_json
  end

  res[0].to_json
end

post '/api/coupons' do 
  return if authenticate? == false
  
    if @data['name'].nil? || @data['description'].nil? || @data['logo_url'].nil?
    status 400
    return { :error => 'Incomplete POST Data' }.to_json
  end

  if @data['description'].length >= 1000
    status 400
    return { :error => 'Description Length > 1000' }.to_json
  end

  res = @conn.exec('SELECT id
                    FROM coupons
                    WHERE description = $1
                    AND logo_url = $2 AND name = $3', [@data['description'], @data['logo_url'], @data['logo_url']])

  if res.num_tuples != 0
    status 400
    return { :error => 'Coupon Already Exists' }.to_json
  end

  @conn.exec('INSERT INTO coupons (name, description, logo_url, owner_id, creator_id, amount, price, coupontype, expirydate)
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
              [@data['name'], @data['description'], @data['logo_url'], @user_id, @user_id, 1, @data['price'], @data['coupontype'], @data['expirydate']])
  status 201
  { :status => 'CREATED' }.to_json
end

get '/api/coupons' do
  return if authenticate? == false

  res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate
                   FROM coupons')

  coupons = []
  res.each { |row|
    coupons.push(row)
  }

  coupons.to_json
end

get '/api/coupons/:id' do |id|
  return if authenticate? == false

  res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate
                   FROM coupons
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'Coupon Not Found' }.to_json
  end

  res[0].to_json
end
