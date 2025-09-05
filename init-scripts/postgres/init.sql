-- PostgreSQL initialization script
-- This script runs when the PostgreSQL container is first started
-- It creates necessary databases, users, and permissions

-- Create application database if it doesn't exist
CREATE DATABASE app_database;

-- Create application user with limited permissions
CREATE USER app_user WITH PASSWORD 'change_this_password_in_production';

-- Grant permissions to the application user
GRANT CONNECT ON DATABASE app_database TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_user;

-- Create read-only user for reporting
CREATE USER readonly_user WITH PASSWORD 'change_this_password_in_production';
GRANT CONNECT ON DATABASE app_database TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO readonly_user;

-- Create admin user for maintenance
CREATE USER admin_user WITH PASSWORD 'change_this_password_in_production';
GRANT ALL PRIVILEGES ON DATABASE app_database TO admin_user;

-- Connect to the application database to create extensions or initial schema
\c app_database

-- Add any extensions you need
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create initial schema (example)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add any initial data if needed
-- INSERT INTO users (username, email, password_hash) VALUES
--    ('admin', 'admin@example.com', crypt('initial_password', gen_salt('bf')));
