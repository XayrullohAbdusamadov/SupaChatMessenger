-- ==============================================================================
-- SUPACHAT MESSENGER - SUPABASE DATABASE & STORAGE SCHEMA
-- ==============================================================================
-- Run this SQL in your Supabase Dashboard: SQL Editor -> New Query -> Run.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. PROFILES TABLE (profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    about TEXT DEFAULT 'Hey there! I am using SupaChat.',
    role VARCHAR(100),
    phone_number VARCHAR(30),
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. CHATS TABLE (chats)
CREATE TABLE IF NOT EXISTS public.chats (
    id TEXT PRIMARY KEY,
    is_group BOOLEAN DEFAULT false,
    group_name VARCHAR(100),
    group_avatar TEXT,
    created_by TEXT,
    admin_ids TEXT[] DEFAULT '{}',
    blocked_member_ids TEXT[] DEFAULT '{}',
    last_message_text TEXT,
    last_message_type VARCHAR(20) DEFAULT 'text',
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. CHAT PARTICIPANTS (chat_participants)
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    unread_count INT DEFAULT 0,
    last_read_message_id TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

-- 5. MESSAGES TABLE (messages)
CREATE TABLE IF NOT EXISTS public.messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    reply_to_id TEXT,
    message_type VARCHAR(20) DEFAULT 'text',
    content TEXT,
    media_url TEXT,
    media_size BIGINT,
    file_name TEXT,
    voice_duration INT,
    status VARCHAR(20) DEFAULT 'sent',
    is_edited BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    reactions TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. STORIES TABLE (stories)
CREATE TABLE IF NOT EXISTS public.stories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    media_url TEXT NOT NULL,
    caption TEXT,
    is_video BOOLEAN DEFAULT false,
    viewed_by_users TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. BLOCKED USERS TABLE (blocked_users)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id TEXT PRIMARY KEY,
    blocker_id TEXT NOT NULL,
    blocked_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- 8. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- 9. ENABLE REALTIME PUBLICATION
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chats') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'chat_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.chats REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- 10. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Clean existing policies
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
DROP POLICY IF EXISTS "chats_select_policy" ON public.chats;
DROP POLICY IF EXISTS "chats_insert_policy" ON public.chats;
DROP POLICY IF EXISTS "chats_update_policy" ON public.chats;
DROP POLICY IF EXISTS "chat_participants_select_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_update_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;
DROP POLICY IF EXISTS "stories_select_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_insert_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_delete_policy" ON public.stories;
DROP POLICY IF EXISTS "blocked_users_all_policy" ON public.blocked_users;

-- Create open policies for messaging
CREATE POLICY "profiles_select_policy" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_policy" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE USING (true);

CREATE POLICY "chats_select_policy" ON public.chats FOR SELECT USING (true);
CREATE POLICY "chats_insert_policy" ON public.chats FOR INSERT WITH CHECK (true);
CREATE POLICY "chats_update_policy" ON public.chats FOR UPDATE USING (true);

CREATE POLICY "chat_participants_select_policy" ON public.chat_participants FOR SELECT USING (true);
CREATE POLICY "chat_participants_insert_policy" ON public.chat_participants FOR INSERT WITH CHECK (true);
CREATE POLICY "chat_participants_update_policy" ON public.chat_participants FOR UPDATE USING (true);

CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (true);
CREATE POLICY "messages_insert_policy" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "messages_delete_policy" ON public.messages FOR DELETE USING (true);

CREATE POLICY "stories_select_policy" ON public.stories FOR SELECT USING (true);
CREATE POLICY "stories_insert_policy" ON public.stories FOR INSERT WITH CHECK (true);
CREATE POLICY "stories_delete_policy" ON public.stories FOR DELETE USING (true);

CREATE POLICY "blocked_users_all_policy" ON public.blocked_users FOR ALL USING (true);

-- 11. STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;
