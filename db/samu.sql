  CREATE TABLE roles (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    role TEXT UNIQUE
  );

  CREATE TABLE users (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
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
