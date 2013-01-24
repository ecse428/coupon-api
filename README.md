# Coupon API

The coupon API's documentation and spec will be listed here

## Instalation

First be sure to have ruby installed, I have built this using 1.9.3 but any version greater than 1.8 should work.

#### Git

As this is a git based project, git must be installed to grab the source code. Once it is installed clone the project with ```git clone https://github.com/ecse428/coupon-api.git```

#### Version Manager

Next I would advise a ruby version management tool.

###### OSX/Linux

For information on how to install rbenv see [rbenv-github](https://github.com/sstephenson/rbenv)

###### Windows

For information of how to install pik see [pik-github](https://github.com/vertiginous/pik)


#### Bundler

Bundler is used to keep all of the gems required in sync. To install bundler run ```gem install bundler```. Once bundler is installed cd into the project directory and run ```bundle install``` to install all the required gems.

#### Running the server

Once all the gems are installed run ```bundle exec rackup``` to start the server on port 9292.

#### Testing the server

To test the server run ```curl -X GET http://localhost:9292/``` and it should return ```{"status": "OK"}```

## Authentication

To use a route which requires authentication, basically every route other than '/login' and '/', the request must include a 'user_key' and 'key' cookie.

To obtain these cookies the user must first call '/login' as follows:

```
curl -X POST http://localhost:9292 -d '{"username": "INSER USERNAME HERE", "password": "INSERT PASSWORD HERE"}'
```

Which will return the following JSON:

```
{
	"id": "1",
	"username": "alex",
	"user_key": "1:alex",
	"key": "$2a$10hWo38YBa6g4Dya6F2iNbcu638BXjcL.kyq"
}
```

Then a request requiring authentication can be made, for example:

```
curl -X GET http://localhost:9292/coupons -b "user_key=1:alex;key=$2a$10hWo38YBa6g4Dya6F2iNbcu638BXjcL.kyq"
```

## Routes

### COUPONS

######GET /coupons

Returns a list of all coupons

```
[
	{
		"id": "1",
		"name": "first",
		"description": "Test descriptions.",
		"logo_url": "http://s3.amazonaws.com"
	}
]
```

######GET /coupons/:id

Returns a single coupon with id == id or a 404

```
{
	"id": "1",
	"name": "first",
	"description": "Test descriptions.",
	"logo_url": "http://s3.amazonaws.com"
}
```

### USERS

######GET /users/:id


Returns the basic info about a user with id == id or a 404

```
{
	"id": "1",
	"username": "alex"
	"email": "alex.louis.angelini@gmail.com"
}
```