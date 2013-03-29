require 'sinatra'
require 'json'
require 'pg'
require 'bcrypt'

SECRET = 'S3KR3T-K3Y'

set :public_folder, '../coupon-client'
set :views, '../coupon-client/views'
use Rack::MethodOverride

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

 begin
	@conn = PG.connect(:dbname => 'coupon')
 rescue
	halt 500, {:error => 'Cannot connect to the database'}.to_json
 end

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
				@data['address'], @data['phonenumber'], false, @data['accounttype'], @data['paypalaccountname'],
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

 if @data['email'] != nil and @data['email'] != ''
	@conn.exec('UPDATE users SET email=$1
				WHERE id = $2', [@data['email'], id])
 end

 if @data['address'] != nil and @data['address'] != ''
	@conn.exec('UPDATE users SET address=$1
				WHERE id = $2', [@data['address'], id])
 end

 if @data['phone'] != nil and @data['phone'] != ''
	@conn.exec('UPDATE users SET phonenumber=$1
				WHERE id = $2', [@data['phone'], id])
 end

 if @data['paypal'] != nil and @data['paypal'] != ''
	@conn.exec('UPDATE users SET paypalaccountnumber=$1
				WHERE id = $2', [@data['paypal'], id])
 end

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

 @conn.exec('INSERT INTO coupons (name, description, logo_url, owner_id, creator_id, amount, price, expirydate, published, publishing)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
			 [@data['name'], @data['description'], @data['logo_url'], @user_id, @user_id, @data['amount'], @data['price'], @data['date'], false, false])

 status 201
 { :status => 'CREATED' }.to_json
end

put '/api/coupons/:id' do |id|
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
					AND logo_url = $2 AND name = $3 AND id <> $4', 
					[@data['description'], @data['logo_url'], @data['name'], id])

 if res.num_tuples != 0
	status 400
	return { :error => 'Coupon Already Exists' }.to_json
 end
 
 if @data['name'] != nil and @data['name'] != ''
	@conn.exec('UPDATE coupons SET name=$1
				WHERE id = $2', [@data['name'], id])
 end
 
 if @data['description'] != nil and @data['description'] != ''
	@conn.exec('UPDATE coupons SET description=$1
				WHERE id = $2', [@data['description'], id])
 end
 
 if @data['logo_url'] != nil and @data['logo_url'] != ''
	@conn.exec('UPDATE coupons SET logo_url=$1
				WHERE id = $2', [@data['logo_url'], id])
 end
 
 if @data['amount'] != nil and @data['amount'] != ''
	@conn.exec('UPDATE coupons SET amount=$1
				WHERE id = $2', [@data['amount'], id])
 end
 
 if @data['price'] != nil and @data['price'] != ''
	@conn.exec('UPDATE coupons SET price=$1
				WHERE id = $2', [@data['price'], id])
 end
 
 if @data['logo_url'] != nil and @data['date'] != ''
	@conn.exec('UPDATE coupons SET date=$1
				WHERE id = $2', [@data['date'], id])
 end
 
 status 201
 { :status => 'MODIFIED' }.to_json
end

delete '/api/coupons/:id' do |id|
  return if authenticate?(true) == false
  @conn.exec('DELETE FROM coupons WHERE id = $1', [id])
			  
  status 201
  { :status => 'DELETED' }.to_json 
end

get '/api/coupons' do
 #I want (publishing = true OR owner_id = $1) AND amount > 0
 split = request.cookies['user_key'].split(":")
 @user_id = Integer(split[0])
 
 res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate, useramountlimit
					FROM coupons
					WHERE (publishing = true OR owner_id = $1) AND amount > 0', [@user_id])

 coupons = []
 res.each { |row| coupons.push(row) }

 {:status => 'OK', :data => coupons}.to_json
end

get '/api/mycoupons' do
 split = request.cookies['user_key'].split(":")
 @user_id = Integer(split[0])

 res = @conn.exec('SELECT id, name, description, logo_url, owner_id, amount, price, coupontype, expirydate, useramountlimit, published, publishing
					FROM coupons
					WHERE owner_id = $1', [@user_id])

 coupons = []
 res.each { |row| coupons.push(row) }

 {:status => 'OK', :data => coupons}.to_json
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

 users = []
 res.each { |row| users.push(row) }

 {:status => 'OK', :data => users}.to_json
end

post '/api/coupon_search' do
 return if authenticate?(true) == false

 res = @conn.exec('SELECT * FROM coupons
					WHERE name LIKE $1', ['%' + @data['couponname'] + '%'])

 coupons = []
 res.each { |row| coupons.push(row) }

 {:status => 'OK', :data => coupons}.to_json
end

get '/api/users/:id/purchased' do |id|
 return if authenticate?(true) == false

 if @user_id != Integer(id)
	status 403
	return { :error => 'Cannot view other user\'s purchases' }.to_json
 end

 res = @conn.exec('SELECT coupons.id, coupons.name, coupons.description, coupons.logo_url, coupons.price,
							purchased_quantity, claimed_quantity
					FROM purchased_coupons
					JOIN coupons ON (coupons.id = purchased_coupons.coupon_id)
					WHERE purchased_coupons.owner_id = $1',
					[@user_id])

 coupons = []
 res.each { |row| coupons.push(row) }

 {:status => 'ok', :data => coupons}.to_json
end

post '/api/coupons/:id/buy' do |id|
 return if authenticate?(true) == false

 purchased = Integer(@data['purchased_quantity']) rescue 0

 res = @conn.exec('SELECT amount FROM coupons WHERE id = $1', [id])

 if res.num_tuples == 0
	status 404
	return { :error => 'Coupon Not Found' }.to_json
 end

 amount = Integer(res.getvalue(0, 0))
 if amount < purchased
	status 400
	return { :error => "There are only #{amount} available" }.to_json
 end

 @conn.exec('INSERT INTO purchased_coupons (owner_id, coupon_id, purchased_quantity, claimed_quantity, purchase_time)
			 VALUES ($1, $2, $3, $4, $5)',
			 [@user_id, id, purchased, 0, Time.new])

 @conn.exec('UPDATE coupons
			 SET amount = $1
			 WHERE id = $2',
			 [amount - purchased, id])

 {:status => 'OK'}.to_json
end

put '/api/coupons/publish/:id' do |id|
  return if authenticate?(true) == false
  
  res = @conn.exec('SELECT published, publishing 
                    FROM coupons 
                    WHERE id = $1', 
                    [id])
  
  if res.num_tuples == 0
	status 404
	return { :error => 'Coupon Not Found' }.to_json
  end
  
  #if published before, cannot re-publish
  if (res.getvalue(0,0) == true)
    status 404
    return { :error => 'Cannot Re-Publish Coupon' }.to_json
  end
  
  #if being published right now, cannot publish
  if (res[0][1] == true)
    status 404
    return { :error => 'Cannot Publish Publishing Coupon' }.to_json
  end
  
  @conn.exec('UPDATE coupons
              SET published = $1, publishing = $2
              WHERE id = $3',
              [true, true, id])
              
  {:status => 'OK'}.to_json
end

put '/api/coupons/unpublish/:id' do |id|
  return if authenticate?(true) == false
  
  res = @conn.exec('SELECT published, publishing 
                    FROM coupons 
                    WHERE id = $1', 
                    [id])
  
  if res.num_tuples == 0
	status 404
	return { :error => 'Coupon Not Found' }.to_json
  end
  
  #if non-publishing, cannot unpublish
  if (res[0][1] == false)
    status 404
    return { :error => 'Cannot unpublish a non-publishing coupon' }.to_json
  end
  
  @conn.exec('UPDATE coupons
              SET publishing = $1
              WHERE id = $2',
              [false, id])
              
  {:status => 'OK'}.to_json
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

get '/api/ui/editcoupon' do
 return {
	:status => 'OK',
	:tmpl => {
	 :nav => (erb :editcoupon_nav, :layout => :nulllayout),
	 :content => (erb :editcoupon_content, :layout => :nulllayout)
	}
 }.to_json
end

get '/api/ui/deletecoupon' do
 return {
	:status => 'OK',
	:tmpl => {
	 :nav => (erb :deletecoupon_nav, :layout => :nulllayout),
	 :content => (erb :deletecoupon_content, :layout => :nulllayout)
	}
 }.to_json
end

get '/api/ui/purchasedcoupon' do
 return {
	:status => 'OK',
	:tmpl => {
	 :nav => (erb :purchasedcoupon_nav, :layout => :nulllayout),
	 :content => (erb :purchasedcoupon_content, :layout => :nulllayout)
	}
 }.to_json
end

get '/api/ui/managecoupon' do
 return {
	:status => 'OK',
	:tmpl => {
	 :nav => (erb :managecoupon_nav, :layout => :nulllayout),
	 :content => (erb :managecoupon_content, :layout => :nulllayout)
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
