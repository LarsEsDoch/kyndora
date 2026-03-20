-- Enable extension for UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. User table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    partner_id UUID REFERENCES users(id), -- Link for the pair system
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Device table
CREATE TABLE devices (
    mac_address VARCHAR(17) PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    last_heartbeat TIMESTAMP WITH TIME ZONE,
    battery_level INTEGER DEFAULT 100,
    firmware_version VARCHAR(20)
);

-- 3. Content-Feed (Messages & Doodles)
CREATE TABLE content_feed (
    id SERIAL PRIMARY KEY,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content_type VARCHAR(20) NOT NULL, -- 'text', 'doodle', 'mood'
    payload TEXT NOT NULL,             -- Text message or path to image/S3 URL
    is_displayed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tamagotchi Status
CREATE TABLE tamagotchi_state (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    happiness INTEGER DEFAULT 100,
    hunger INTEGER DEFAULT 0,
    last_interaction TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Special days (calendar)
CREATE TABLE special_events (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    event_date DATE NOT NULL,
    event_name VARCHAR(100) NOT NULL,
    display_config JSONB -- Save icons or color codes.
);