CREATE TABLE users (
    id serial PRIMARY KEY,
    username varchar(200),
    email varchar(200),
    password varchar(60),
    firstname varchar(200),
    lastname varchar(200),
	address varchar(200),
	phonenumber varchar(200),
	suspended boolean,
	accounttype varchar(200)
);

CREATE TABLE coupons (
    id serial PRIMARY KEY,
    name varchar(100),
	coupontype varchar(300),
    description varchar(1000),
    logo_url varchar(200),
	owner_id serial,
	creator_id serial,
	amount integer,
	price float,
	expirydate date,
	FOREIGN KEY (owner_id) REFERENCES users(id),
	FOREIGN KEY (creator_id) REFERENCES users(id)
);
