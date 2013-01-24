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
    logo_url varchar(200)
);
