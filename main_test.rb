require './main.rb'
require 'test/unit'
require 'rack/test'
require 'sinatra'
require 'json'
require 'pg'
require 'bcrypt'

set :environment, :test

##############################################################################################
#Test assumes in the database there is a user called alex with id 1 and password 12345678.
##############################################################################################

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
 #########################################################################
 #Test get requests
 #########################################################################
	
  def test_simple_func
    get '/api'
	assert last_response.ok?
	assert_equal '{"status":"OK"}', last_response.body
  end
  
  def test_get_coupons  
	clear_cookies
    set_cookie "key=$2a$10$AffqH1SQKfuD3Gn988nwGOHY33H5p2KingOHLoSLhQEIXVLOHpPgy"
	set_cookie "user_key=1:alex"
	get  '/api/coupons'
	assert last_response.ok?
  end
  
  def test_get_user
	clear_cookies
    set_cookie "key=$2a$10$AffqH1SQKfuD3Gn988nwGOHY33H5p2KingOHLoSLhQEIXVLOHpPgy"
	set_cookie "user_key=1:alex"
    get  '/api/users/1'
	assert last_response.ok?
  end
  
  def test_get_user_coupon
	clear_cookies
    set_cookie "key=$2a$10$AffqH1SQKfuD3Gn988nwGOHY33H5p2KingOHLoSLhQEIXVLOHpPgy"
	set_cookie "user_key=1:alex"
	get '/api/coupons/1'
	assert last_response.ok?
  end
 ##############################################
 #Test post requests
 ############################################## 
  def test_login
	clear_cookies
	
	#missing password or email to login
    post '/api/login', {:data => nil}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Email or Username Required"}', last_response.body
	
	#invalid user (non registred user)
    post '/api/login', {:username => "xmlk" , :password => "12345678"}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"User Not Found"}', last_response.body
	
	#username given but password missing
	post '/api/login', {:username => "alex"}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Password Required"}', last_response.body
	
	#username but invalid password given
	post '/api/login', {:username => "alex", :password => "test"}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Password Does Not Match"}', last_response.body
	
	#valid username and password given
	post '/api/login', {:username => "alex", :password => "12345678"}.to_json, "CONTENT_TYPE" => "application/json"
	assert_not_equal '{"error":"Password Does Not Match"}', last_response.body
	assert_not_equal '{"error":"Password Required"}', last_response.body
	assert_not_equal '{"error":"Email or Username Required"}', last_response.body
  end 
  
  def test_registration
	clear_cookies
	
	#missing username
	post '/api/users', {:username => nil, :password => "12345678" , :email => 'trail@test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
	#missing password
	post '/api/users', {:username => "charles", :password => nil , :email => 'trail@test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
	#missing email
	post '/api/users', {:username => "charles", :password => "12345678" , :email => nil}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
	#Password length too small
	post '/api/users', {:username => "charles", :password => "12345" , :email => 'trail@test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Password Length < 8"}', last_response.body
	
	#Username already exists
	post '/api/users', {:username => "alex", :password => "12345678" , :email => 'test@test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Username/Email Already Taken"}', last_response.body
	
  end
  
  def test_create_coupon
	clear_cookies
	set_cookie "key=$2a$10$AffqH1SQKfuD3Gn988nwGOHY33H5p2KingOHLoSLhQEIXVLOHpPgy"
	set_cookie "user_key=1:alex"
	
	#invalid coupon name
	post '/api/users', {:name => nil, :description => "12345678" , :logo_url => 'www.test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
	#invalid description name
	post '/api/users', {:name => "boston_pizza", :description => nil , :logo_url => 'www.test.com'}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
	#invalid logo_url name
	post '/api/users', {:name => "boston_pizza", :description => "12345678" , :logo_url => nil}.to_json, "CONTENT_TYPE" => "application/json"
	assert_equal '{"error":"Incomplete POST Data"}', last_response.body
	
  end
  

  
  
end