ALTER SYSTEM SET max_connections = 1000;
ALTER SYSTEM RESET shared_buffers;
CREATE DATABASE fts_with_pg;
CREATE USER dtc WITH PASSWORD 'dtc';
GRANT ALL PRIVILEGES ON DATABASE "fts_with_pg" to dtc;
