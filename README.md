# Coupon API

The coupon API's documentation and spec will be listed here

## Installation

First be sure to have ruby installed, I have built this using 1.9.3 but any version greater than 1.8 should work.

#### Git

As this is a git based project, git must be installed to grab the source code. Once it is installed clone the project with:

```
$ git clone https://github.com/ecse428/coupon-api.git
```

The application also requires the client code to be in a sibling directory. So after cloning the coupon-api run:

```
$ cd ..
$ git clone https://github.com/ecse428/coupon-client.git
```

After both repos have been cloned you should have a directory as follows:

```
├── coupon-api
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── Guardfile
│   ├── README.md
│   ├── config.ru
│   ├── main.rb
│   └── tables.sql
└── coupon-client
    ├── index.html
    └── vendor
        └── jquery.js
```

#### Version Manager

Next I would advise a ruby version management tool.

###### OSX/Linux

For information on how to install rbenv see [rbenv-github](https://github.com/sstephenson/rbenv)

###### Windows

For information of how to install pik see [pik-github](https://github.com/vertiginous/pik)


#### Bundler

Bundler is used to keep all of the gems required in sync. To install bundler run ```gem install bundler```. Once bundler is installed cd into the project directory and run ```bundle install``` to install all the required gems.

#### Database

The API is built using a Postgres database, mostly because it's the best open source SQL option out there and we get a free dev instance when we will launch this on Heroku. Google how to set up Postgres the internet is filled with tutorials for each platform, for OSX I would suggest [Postgres.app](http://postgresapp.com/).

Once the database is installed make sure it is running and create a database named: ```coupon```. For dev purposes I did not put a password requirement on the database.

The run the ```CREATE TABLE``` statements in ```tables.sql``` to build the appropriate tables.

#### Running the server

Once all the gems are installed and the database is running, run ```bundle exec rackup``` to start the server on port 9292.

#### Testing the server

To test the server run ```curl -X GET http://localhost:9292/api``` and it should return ```{"status": "OK"}```

## Client

The client code is kept in the following Github repo: [coupon-client](https://github.com/ecse428/coupon-client). All the HTML, CSS and JS for the application is kept in that separate repo. The API, for simplicity reasons, will actually serve the static assets, this is why both git repos are kept as directory siblings.

## Authentication

Firs things first, make sure your database contains a user. You can create a user with the following curl command:

```
curl -X POST http://localhost:9292/api/users -d '{"username": "INSERT USERNAME HERE", "password": "INSERT PASSWORD HERE", "email": "INSERT EMAIL HERE"}'
```

To use a route which requires authentication, basically every route other than '/login' and '/', the request must include a 'user_key' and 'key' cookie.

To obtain the appropriate login cookies the user must first call '/login' as follows:

```
curl -X POST http://localhost:9292/api/login -d '{"username": "INSER USERNAME HERE", "password": "INSERT PASSWORD HERE"}'
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
curl -X GET http://localhost:9292/api/coupons -b "user_key=1:alex;key=$2a$10hWo38YBa6g4Dya6F2iNbcu638BXjcL.kyq"
```

## Routes

### COUPONS

###### GET /api/coupons

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

###### GET /api/coupons/:id

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

###### GET /api/users/:id


Returns the basic info about a user with id == id or a 404

```
{
	"id": "1",
	"username": "alex"
	"email": "alex.louis.angelini@gmail.com"
}
```