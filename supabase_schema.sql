-- ==============================================================================
-- SUPACHAT MESSENGER - SUPABASE DATABASE & STORAGE SCHEMA
-- ==============================================================================
-- Run this SQL in your Supabase Dashboard: SQL Editor -> New Query -> Run.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. FOYDALANUVCHILAR PROFILLARI JADVALI (profiles)
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

-- Ustunlar mavjudligini tekshirib qo'shish (eski jadvallar uchun):
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number VARCHAR(30);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS about TEXT DEFAULT 'Hey there! I am using SupaChat.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 3. CHATLAR VA GURUHLAR JADVALI (chats)
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
    last_message_sender_id TEXT,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS blocked_member_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_text TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_type VARCHAR(20) DEFAULT 'text';
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_sender_id TEXT;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();

-- 4. CHAT ISHTIROKCHILARI JADVALI (chat_participants)
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    unread_count INT DEFAULT 0,
    last_read_message_id TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;
ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS last_read_message_id TEXT;

-- 5. XABARLAR JADVALI (messages)
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

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reply_to_id TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS voice_duration INT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_size BIGINT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS file_name TEXT;

-- 6. FOYDALANUVCHI QURILMALARI JADVALI (user_devices - FCM Push Tokens)
CREATE TABLE IF NOT EXISTS public.user_devices (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_name TEXT,
    platform TEXT, -- 'android' | 'ios' | 'web'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

ALTER TABLE IF EXISTS public.user_devices DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey;

-- 7. STORYLAR JADVALI (stories)
CREATE TABLE IF NOT EXISTS public.stories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    media_url TEXT NOT NULL,
    caption TEXT,
    is_video BOOLEAN DEFAULT false,
    viewed_by_users TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. BLOKLANGAN FOYDALANUVCHILAR JADVALI (blocked_users)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id TEXT PRIMARY KEY,
    blocker_id TEXT NOT NULL,
    blocked_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- 9. INDEXLAR (Tezkor yuklash va qidiruv uchun)
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON public.messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_id ON public.chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);

-- 10. DETERMINISTIK BIRGA-BIR SUHBAT YARATISH VA TOPISH FUNKSIYASI (get_or_create_conversation)
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
    p_user1_id TEXT,
    p_user2_id TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user1 public.profiles%ROWTYPE;
    v_user2 public.profiles%ROWTYPE;
    v_u1_clean TEXT;
    v_u2_clean TEXT;
    v_chat_id TEXT;
    v_chat public.chats%ROWTYPE;
    v_user1_actual_id TEXT;
    v_user2_actual_id TEXT;
BEGIN
    -- 1. Foydalanuvchilarni profil jadvalidan aniqlash (id yoki username orqali)
    SELECT * INTO v_user1 FROM public.profiles 
    WHERE id = p_user1_id OR username = lower(trim(replace(p_user1_id, '@', ''))) OR id = ('user-' || lower(trim(replace(p_user1_id, '@', ''))))
    LIMIT 1;

    SELECT * INTO v_user2 FROM public.profiles 
    WHERE id = p_user2_id OR username = lower(trim(replace(p_user2_id, '@', ''))) OR id = ('user-' || lower(trim(replace(p_user2_id, '@', ''))))
    LIMIT 1;

    -- Username'larni tozalash
    IF v_user1.username IS NOT NULL THEN
        v_u1_clean := lower(trim(replace(v_user1.username, '@', '')));
        v_user1_actual_id := v_user1.id;
    ELSE
        v_u1_clean := lower(trim(replace(replace(p_user1_id, 'user-', ''), '@', '')));
        v_user1_actual_id := p_user1_id;
    END IF;

    IF v_user2.username IS NOT NULL THEN
        v_u2_clean := lower(trim(replace(v_user2.username, '@', '')));
        v_user2_actual_id := v_user2.id;
    ELSE
        v_u2_clean := lower(trim(replace(replace(p_user2_id, 'user-', ''), '@', '')));
        v_user2_actual_id := p_user2_id;
    END IF;

    -- 2. Deterministik UUID v5 hisoblash (alfabit bo'yicha saralangan usernames)
    v_chat_id := uuid_generate_v5(
        '6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid,
        'supachat:direct:' || LEAST(v_u1_clean, v_u2_clean) || ':' || GREATEST(v_u1_clean, v_u2_clean)
    )::text;

    -- 3. Suhbat qatorini chats jadvalida ta'minlash
    INSERT INTO public.chats (id, is_group, created_by, created_at)
    VALUES (v_chat_id, false, v_user1_actual_id, NOW())
    ON CONFLICT (id) DO NOTHING;

    -- 4. Ikkala ishtirokchini ham chat_participants jadvaliga qo'shish
    INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
    VALUES 
        (v_chat_id, v_user1_actual_id, 'member', 0),
        (v_chat_id, v_user2_actual_id, 'member', 0)
    ON CONFLICT (chat_id, user_id) DO NOTHING;

    -- Moslik uchun username/alias identifikatorlarini ham kiritish
    IF v_user1_actual_id != v_u1_clean THEN
        INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
        VALUES (v_chat_id, v_u1_clean, 'member', 0)
        ON CONFLICT (chat_id, user_id) DO NOTHING;
    END IF;
    IF v_user2_actual_id != v_u2_clean THEN
        INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
        VALUES (v_chat_id, v_u2_clean, 'member', 0)
        ON CONFLICT (chat_id, user_id) DO NOTHING;
    END IF;

    SELECT * INTO v_chat FROM public.chats WHERE id = v_chat_id;

    RETURN jsonb_build_object(
        'id', v_chat_id,
        'is_group', false,
        'created_by', v_chat.created_by,
        'last_message_text', v_chat.last_message_text,
        'last_message_type', v_chat.last_message_type,
        'last_message_sender_id', v_chat.last_message_sender_id,
        'last_message_at', v_chat.last_message_at,
        'created_at', v_chat.created_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. AVTOMATIK SUHBAT YARATUVCHI VA YANGILOVCHI DATABASE TRIGGER
CREATE OR REPLACE FUNCTION public.handle_new_message_conversation()
RETURNS TRIGGER AS $$
DECLARE
  v_preview TEXT;
BEGIN
  IF NEW.message_type = 'image' THEN v_preview := '📷 Photo';
  ELSIF NEW.message_type = 'video' THEN v_preview := '🎥 Video';
  ELSIF NEW.message_type = 'voice' THEN v_preview := '🎤 Voice message';
  ELSIF NEW.message_type = 'doc' THEN v_preview := '📄 Document';
  ELSE v_preview := NEW.content;
  END IF;

  -- 1. Suhbat mavjudligini ta'minlash yoki yangilash
  INSERT INTO public.chats (id, is_group, created_by, last_message_text, last_message_type, last_message_sender_id, last_message_at)
  VALUES (NEW.chat_id, false, NEW.sender_id, v_preview, NEW.message_type, NEW.sender_id, NEW.created_at)
  ON CONFLICT (id) DO UPDATE SET
    last_message_text = v_preview,
    last_message_type = NEW.message_type,
    last_message_sender_id = NEW.sender_id,
    last_message_at = NEW.created_at;

  -- 2. Yuboruvchini ishtirokchi sifatida qo'shish
  INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
  VALUES (NEW.chat_id, NEW.sender_id, 'member', 0)
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  -- 3. [YANGI] Agar receiver_id mavjud bo'lsa, qabul qiluvchini ham ishtirokchi sifatida kafolatlash
  --    Bu getOrCreateDirectConversation muvaffaqiyatsiz bo'lganda ham xavfsizlik to'ri bo'lib xizmat qiladi
  IF NEW.receiver_id IS NOT NULL THEN
    INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
    VALUES (NEW.chat_id, NEW.receiver_id, 'member', 1)
    ON CONFLICT (chat_id, user_id) DO UPDATE
      SET unread_count = public.chat_participants.unread_count + 1;
  END IF;

  -- 4. Qolgan barcha ishtirokchilar (guruh chat)da o'qilmagan xabarlar sonini oshirish
  --    receiver_id allaqachon yuqorida qayta hisobga olingan, ikki marta hisoblash oldini olish
  UPDATE public.chat_participants
  SET unread_count = unread_count + 1
  WHERE chat_id = NEW.chat_id
    AND user_id != NEW.sender_id
    AND (NEW.receiver_id IS NULL OR user_id != NEW.receiver_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_new_message_conversation ON public.messages;
CREATE TRIGGER trg_new_message_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_conversation();


-- 12. DUBLIKAT SUHBATLARNI BIRLASHTIRISH VA TOZALASH SKRIPTI (Database Cleanup Helper)
CREATE OR REPLACE FUNCTION public.cleanup_and_merge_duplicate_conversations()
RETURNS VOID AS $$
DECLARE
    r RECORD;
    v_canonical_id TEXT;
    v_u1 TEXT;
    v_u2 TEXT;
BEGIN
    -- Har bir 1-on-1 suhbat ishtirokchilarini tahlil qilish
    FOR r IN (
        SELECT cp1.chat_id, cp1.user_id as u1, cp2.user_id as u2, c.is_group
        FROM public.chat_participants cp1
        JOIN public.chat_participants cp2 ON cp1.chat_id = cp2.chat_id AND cp1.user_id < cp2.user_id
        JOIN public.chats c ON c.id = cp1.chat_id
        WHERE c.is_group = false
    ) LOOP
        -- Canonical ID hisoblash
        SELECT lower(trim(replace(username, '@', ''))) INTO v_u1 FROM public.profiles WHERE id = r.u1;
        IF v_u1 IS NULL THEN v_u1 := lower(trim(replace(r.u1, 'user-', ''))); END IF;

        SELECT lower(trim(replace(username, '@', ''))) INTO v_u2 FROM public.profiles WHERE id = r.u2;
        IF v_u2 IS NULL THEN v_u2 := lower(trim(replace(r.u2, 'user-', ''))); END IF;

        v_canonical_id := uuid_generate_v5(
            '6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid,
            'supachat:direct:' || LEAST(v_u1, v_u2) || ':' || GREATEST(v_u1, v_u2)
        )::text;

        -- Agar eski chat_id kanonik bo'lmasa, ma'lumotlarni ko'chirish
        IF r.chat_id != v_canonical_id THEN
            -- Kanonik suhbat qatorini yaratish
            INSERT INTO public.chats (id, is_group, created_by, created_at)
            VALUES (v_canonical_id, false, r.u1, NOW())
            ON CONFLICT (id) DO NOTHING;

            -- Ishtirokchilarni ko'chirish
            INSERT INTO public.chat_participants (chat_id, user_id, role, unread_count)
            VALUES (v_canonical_id, r.u1, 'member', 0), (v_canonical_id, r.u2, 'member', 0)
            ON CONFLICT (chat_id, user_id) DO NOTHING;

            -- Xabarlarni ko'chirish
            UPDATE public.messages SET chat_id = v_canonical_id WHERE chat_id = r.chat_id;

            -- Qo'ng'iroqlarni ko'chirish
            UPDATE public.calls SET chat_id = v_canonical_id WHERE chat_id = r.chat_id;

            -- Eski dublikat suhbat va ishtirokchilarni o'chirish
            DELETE FROM public.chat_participants WHERE chat_id = r.chat_id;
            DELETE FROM public.chats WHERE id = r.chat_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. REALTIME PUBLICATION SOZLAMALARI
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

-- 12. ROW LEVEL SECURITY (RLS) XAVFSIZLIK SOZLAMALARI
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Eski siyosatlarni tozalash
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
DROP POLICY IF EXISTS "user_devices_select_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_insert_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_update_policy" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_delete_policy" ON public.user_devices;
DROP POLICY IF EXISTS "stories_select_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_insert_policy" ON public.stories;
DROP POLICY IF EXISTS "stories_delete_policy" ON public.stories;
DROP POLICY IF EXISTS "blocked_users_all_policy" ON public.blocked_users;

-- Yangi ruxsat siyosatlari
CREATE POLICY "profiles_select_policy" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_policy" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update_policy" ON public.profiles FOR UPDATE USING (true);

CREATE POLICY "chats_select_policy" ON public.chats FOR SELECT USING (true);
CREATE POLICY "chats_insert_policy" ON public.chats FOR INSERT WITH CHECK (true);
CREATE POLICY "chats_update_policy" ON public.chats FOR UPDATE USING (true);

DROP POLICY IF EXISTS "chat_participants_select_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_update_policy" ON public.chat_participants;
DROP POLICY IF EXISTS "chat_participants_delete_policy" ON public.chat_participants;

CREATE POLICY "chat_participants_select_policy" ON public.chat_participants FOR SELECT USING (true);
CREATE POLICY "chat_participants_insert_policy" ON public.chat_participants FOR INSERT WITH CHECK (true);
CREATE POLICY "chat_participants_update_policy" ON public.chat_participants FOR UPDATE USING (true);
CREATE POLICY "chat_participants_delete_policy" ON public.chat_participants FOR DELETE USING (true);

CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (true);
CREATE POLICY "messages_insert_policy" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "messages_delete_policy" ON public.messages FOR DELETE USING (true);

CREATE POLICY "user_devices_select_policy" ON public.user_devices FOR SELECT USING (true);
CREATE POLICY "user_devices_insert_policy" ON public.user_devices FOR INSERT WITH CHECK (true);
CREATE POLICY "user_devices_update_policy" ON public.user_devices FOR UPDATE USING (true);
CREATE POLICY "user_devices_delete_policy" ON public.user_devices FOR DELETE USING (true);

CREATE POLICY "stories_select_policy" ON public.stories FOR SELECT USING (true);
CREATE POLICY "stories_insert_policy" ON public.stories FOR INSERT WITH CHECK (true);
CREATE POLICY "stories_delete_policy" ON public.stories FOR DELETE USING (true);

CREATE POLICY "blocked_users_all_policy" ON public.blocked_users FOR ALL USING (true);

-- 13. CALLS (OVOZLI VA VIDEO QO'NG'IROQLAR JADVALI)
CREATE TABLE IF NOT EXISTS public.calls (
    id TEXT PRIMARY KEY,
    caller_id TEXT NOT NULL,
    caller_name TEXT NOT NULL,
    caller_avatar_url TEXT,
    receiver_id TEXT NOT NULL,
    receiver_name TEXT NOT NULL,
    receiver_avatar_url TEXT,
    chat_id TEXT NOT NULL,
    call_type VARCHAR(20) DEFAULT 'video', -- 'video' | 'audio'
    status VARCHAR(20) DEFAULT 'ringing',  -- 'ringing' | 'accepted' | 'rejected' | 'ended' | 'missed'
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.calls DROP CONSTRAINT IF EXISTS calls_caller_id_fkey;
ALTER TABLE IF EXISTS public.calls DROP CONSTRAINT IF EXISTS calls_receiver_id_fkey;

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "calls_select_policy" ON public.calls;
DROP POLICY IF EXISTS "calls_insert_policy" ON public.calls;
DROP POLICY IF EXISTS "calls_update_policy" ON public.calls;
CREATE POLICY "calls_select_policy" ON public.calls FOR SELECT USING (true);
CREATE POLICY "calls_insert_policy" ON public.calls FOR INSERT WITH CHECK (true);
CREATE POLICY "calls_update_policy" ON public.calls FOR UPDATE USING (true);

ALTER TABLE public.calls REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'calls'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
    END IF;
END $$;

-- 14. STORAGE BUCKETLARINI SOZLASH
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('voice-messages', 'voice-messages', true),
  ('stories', 'stories', true)
ON CONFLICT (id) DO NOTHING;

-- 15. STORAGE OBJECT RLS POLICIES (Rasm, ovoz va fayllarni yuklash va ko'rish ruxsatlari)
DROP POLICY IF EXISTS "Public storage read" ON storage.objects;
DROP POLICY IF EXISTS "Public storage insert" ON storage.objects;
DROP POLICY IF EXISTS "Public storage update" ON storage.objects;
DROP POLICY IF EXISTS "Public storage delete" ON storage.objects;

CREATE POLICY "Public storage read" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "Public storage insert" ON storage.objects FOR INSERT WITH CHECK (true);
CREATE POLICY "Public storage update" ON storage.objects FOR UPDATE USING (true);
CREATE POLICY "Public storage delete" ON storage.objects FOR DELETE USING (true);

-- 16. AVTOMATIK AUTH USER PROFIL TRIGGERI (phone_number va metadata bilan)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    username,
    full_name,
    avatar_url,
    phone_number,
    about
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'phone_number',
    COALESCE(NEW.raw_user_meta_data->>'about', 'Hey there! I am using SupaChat.')
  )
  ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    full_name = EXCLUDED.full_name,
    phone_number = COALESCE(EXCLUDED.phone_number, public.profiles.phone_number),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


