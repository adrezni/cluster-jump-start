\c feast
CREATE SCHEMA feast AUTHORIZATION feastuser;
create table feast.heart_values
(
    name                STRING,
    age                 INTEGER,
    id                  INTEGER,
    created             TIMESTAMP
);

ALTER DATABASE feast OWNER TO feastuser;
GRANT ALL PRIVILEGES ON DATABASE feast TO feastuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA feast TO feastuser;
