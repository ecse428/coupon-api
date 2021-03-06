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
    accounttype varchar(200),
    paypalaccountname varchar(200),
    creditcardnumber varchar(200),
    creditcardexpirydate date
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
    useramountlimit integer,
    published boolean,
    publishing boolean,
    FOREIGN KEY (owner_id) REFERENCES users(id),
    FOREIGN KEY (creator_id) REFERENCES users(id)
);

CREATE TABLE purchased_coupons (
    id serial PRIMARY KEY,
    owner_id serial,
    coupon_id serial,
    purchased_quantity integer,
    claimed_quantity integer,
    purchase_time date,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id)
);
