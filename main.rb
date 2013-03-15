require 'sinatra'
require 'json'
require 'pg'
require 'bcrypt'

SECRET = 'S3KR3T-K3Y'

set :public_folder, '../coupon-client'
set :views, '../coupon-client/views'


get '/' do
  content_type 'text/html'
  File.read(File.join('..', 'coupon-client', 'index.html'))
end

get '/client-tests' do
  content_type 'text/html'
  File.read(File.join('..', 'coupon-client', 'tests.html'))
end

def authenticate?(status)
  if request.cookies['key'].nil? || request.cookies['user_key'].nil?
    if status == true
      status 403
      response.write({ :error => '"user_key" and "key" Cookie Required' }.to_json)
      response.close()
    end
    return false
  end

  auth = BCrypt::Password.new(request.cookies['key'])
  if auth != (request.cookies['user_key'] + SECRET)
    if status == true
      status 403
      response.write({ :error => 'Invalid Key' }.to_json)
      response.close()
    end
    return false
  end

  split = request.cookies['user_key'].split(":")
  @user_id = Integer(split[0])
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

  res = @conn.exec('SELECT id
                    FROM users
                    WHERE (username = $1 AND suspended = $2)
                    OR (email = $3 AND suspended = $2)',[@data['username'], true, @data['email']])

  if res.num_tuples != 0
    status 403
    return { :error => 'User suspended'}.to_json
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

  user_key = res[0]['id'] + ':' + res[0]['username']
  key = BCrypt::Password.create(user_key + SECRET)
  { :id => res[0]['id'],
    :username => res[0]['username'],
    :user_key => user_key,
    :key => key }.to_json
end

get '/api/login/test' do
  if authenticate?(false)
    { :status => 'OK',
      :user_id => @user_id,
      :username => @username }.to_json
  else
    { :status => false }.to_json
  end
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

  @conn.exec('INSERT INTO users (username, email, password, firstname, lastname,
                                 address, phonenumber, suspended, accounttype, paypalaccountname,
                                 creditcardnumber, creditcardexpirydate)
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)',
              [@data['username'], @data['email'], hash, @data['firstname'], @data['lastname'],
               @data['address'], @data['phonenumber'], false, 'user', @data['paypalaccountname'],
               @data['creditcardnumber'], @data['creditcardexpirydate']])

  status 201
  { :status => 'CREATED' }.to_json
end

get '/api/users/:id' do |id|
  return if authenticate?(true) == false

  res = @conn.exec('SELECT * FROM users
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'User Not Found' }.to_json
  end

  res[0].to_json
end


put '/api/users/:id' do |id|
  return if authenticate?(true) == false

  res = @conn.exec('SELECT id
                    FROM users
                    WHERE email = $1', [@data['email']])

  if res.num_tuples != 0
    status 400
    return { :error => 'Email Already Taken' }.to_json
  end

  @conn.exec('UPDATE users SET email = $1
              WHERE id = $2', [@data['email'], id])
  status 201
  { :status => 'MODIFIED' }.to_json
end

post '/api/coupons' do
  return if authenticate?(true) == false

  if @data['name'].nil? || @data['description'].nil? || @data['logo_url'].nil?
    status 400
    return { :error => 'Incomplete POST Data' }.to_json
  end

  if @data['name'].length < 3
    status 400
    return { :error => 'Coupon name too short < 3!' }.to_json
  end

  if @data['logo_url'].length < 3
    status 400
    return { :error => 'Logo url too short < 3!' }.to_json
  end

  if @data['description'].length < 0
    status 400
    return { :error => 'Description must be included!' }.to_json
  end

  if @data['description'].length >= 1000
    status 400
    return { :error => 'Description Length > 1000' }.to_json
  end

  res = @conn.exec('SELECT id
                    FROM coupons
                    WHERE description = $1
                    AND logo_url = $2 AND name = $3', [@data['description'], @data['logo_url'], @data['name']])

  if res.num_tuples != 0
    status 400
    return { :error => 'Coupon Already Exists' }.to_json
  end

  @conn.exec('INSERT INTO coupons (name, description, logo_url, owner_id, creator_id, amount, price)
              VALUES ($1, $2, $3, $4, $5, $6, $7)',
              [@data['name'], @data['description'], @data['logo_url'], @user_id, @user_id, 1, @data['price']])

#  @conn.exec('INSERT INTO coupons (name, description, logo_url, owner_id, creator_id, amount, price, coupontype, expirydate, useramountlimit)
#              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
#              [@data['name'], @data['description'], @data['logo_url'], @user_id, @user_id, 1, @data['price'], @data['coupontype'], @data['expirydate'], @data['useramountlimit']])
  status 201
  { :status => 'CREATED' }.to_json
end

get '/api/coupons' do
  return if authenticate?(true) == false

  res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate, useramountlimit
                    FROM coupons', [])

  coupons = []
  res.each { |row|
    coupons.push(row)
  }

  {:status => 'OK', :data => coupons}.to_json
end

get '/api/coupons/all' do

  res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate, useramountlimit
                   FROM coupons')

  coupons = []
  res.each { |row| coupons.push(row) }

  {:status => 'ok', :data => coupons}.to_json
end

get '/api/coupons/:id' do |id|
  return if authenticate?(true) == false

  res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate, useramountlimit
                   FROM coupons
                   WHERE id = $1', [id])

  if res.num_tuples == 0
    status 404
    return { :error => 'Coupon Not Found' }.to_json
  end

  {:status => 'ok', :data => res[0]}.to_json
end

post '/api/user_search' do
  return if authenticate?(true) == false

  res = @conn.exec('SELECT id, username, email, firstname, lastname, address, phonenumber, suspended, accounttype FROM users
                    WHERE username LIKE $1', ['%' + @data['username'] + '%'])

  if res.num_tuples == 0
    status 202
    return { :error => 'User Not Found' }.to_json
  end

  users = []
  res.each { |row| users.push(row) }

  {:status => 'OK', :data => users}.to_json
end

post '/api/coupon_search' do
  return if authenticate?(true) == false

  res = @conn.exec('SELECT * FROM coupons
                    WHERE name LIKE $1', ['%' + @data['couponname'] + '%'])

  if res.num_tuples == 0
    status 202
    return { :error => 'Coupon Not Found' }.to_json
  end

  coupons = []
  res.each { |row| coupons.push(row) }

  {:status => 'OK', :data => coupons}.to_json
end

get '/api/ui/register' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :register_nav, :layout => :nulllayout),
      :content => (erb :register_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/index' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :index_nav, :layout => :nulllayout),
      :content => (erb :index_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/guest' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :guest_nav, :layout => :nulllayout),
      :content => (erb :guest_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/profile' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :profile_nav, :layout => :nulllayout),
      :content => (erb :profile_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/editprofile' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :editprofile_nav, :layout => :nulllayout),
      :content => (erb :editprofile_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/createcoupon' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :createcoupon_nav, :layout => :nulllayout),
      :content => (erb :createcoupon_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/settings' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :settings_nav, :layout => :nulllayout),
      :content => (erb :settings_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/search' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :search_nav, :layout => :nulllayout),
      :content => (erb :search_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/user_result' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :search_nav_r, :layout => :nulllayout),
      :content => (erb :user_result, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/coupon_result' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :search_nav_r, :layout => :nulllayout),
      :content => (erb :coupon_result, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/coupondetail' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :coupondetail_nav, :layout => :nulllayout),
      :content => (erb :coupondetail_content, :layout => :nulllayout)
    }
  }.to_json
end

get '/api/ui/testpage' do
  return {
    :status => 'OK',
    :tmpl => {
      :nav => (erb :testpage_nav, :layout => :nulllayout),
      :content => (erb :testpage_content, :layout => :nulllayout)
    }
  }.to_json
end

# Test Bench

get '/api/tests' do
  return if authenticate?(true) == false

  res = @conn.exec('SELECT accounttype
                    FROM users
                    WHERE id = $1', [@user_id])

  if res[0]['accounttype'] != 'admin'
      status 403
      return { :error => 'Admin Only Page' }.to_json
  end

  results = `bundle exec ruby main_test.rb`

  return {:status => 'OK', :res => results}.to_json

end
