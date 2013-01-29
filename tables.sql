CREATE TABLE users (
    id serial PRIMARY KEY,
    username varchar(200),
    email varchar(200),
    password varchar(60)
);

CREATE TABLE coupons (
    id serial PRIMARY KEY,
    name varchar(100),
    description varchar(1000),
    logo_url varchar(200),
	owner_id serial,
	creator_id serial,
	amount integer,
	FOREIGN KEY (owner_id) REFERENCES users(id),
	FOREIGN KEY (creator_id) REFERENCES users(id)
);
