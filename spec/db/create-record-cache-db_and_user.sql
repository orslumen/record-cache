DROP DATABASE IF EXISTS record_cache;
CREATE DATABASE record_cache;
CREATE USER 'record_cache'@'localhost' IDENTIFIED BY 'test';
GRANT ALL ON record_cache.* to 'record_cache'@'localhost';
FLUSH PRIVILEGES;
