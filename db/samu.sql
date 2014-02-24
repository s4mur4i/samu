  CREATE TABLE roles (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    role TEXT UNIQUE
  );

  CREATE TABLE users (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password CHAR(40),
    email    TEXT,
    last_modified DATETIME
  );

  CREATE TABLE user_roles (
    user_id INTEGER REFERENCES users(id),
    role_id INTEGER REFERENCES roles(id),
    PRIMARY KEY(user_id, role_id)
  );
  CREATE TABLE session (
   id		CHAR(72) primary key,
   session_data	text,
   expires	int
  );
  CREATE TABLE user_config (
   user_id   INTEGER REFERENCES users(id),
   config_id  INTEGER REFERENCES config(id),
   data     TEXT,
   PRIMARY KEY(user_id,config_id)
  );
  CREATE TABLE config (
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   name TEXT UNIQUE,
   display BOOLEAN,
   encrypt BOOLEAN
  );
