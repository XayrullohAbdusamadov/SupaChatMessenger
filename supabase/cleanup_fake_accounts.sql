-- ==============================================================================
-- SUPACHAT MESSENGER - FAKE / BOT / SPAM ACCOUNTS CLEANUP SCRIPT
-- ==============================================================================
-- Ushbu skript Supabase SQL Editorida xatoliksiz ishlashi uchun to'liq optimallashgan.
-- Barcha o'chirish amallari bog'liqliklar (Foreign Keys / Cascades) bo'yicha ketma-ket bajariladi.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TOZALASH FUNKSIYASI (Stored Procedure)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_fake_accounts()
RETURNS JSONB AS $$
DECLARE
    v_fake_ids TEXT[];
    v_deleted_messages INT := 0;
    v_deleted_participants INT := 0;
    v_deleted_chats INT := 0;
    v_deleted_profiles INT := 0;
BEGIN
    -- 1. Fake / Demo / Bot akkauntlar ID larini massivga yig'ib olish
    SELECT ARRAY_AGG(id::text) INTO v_fake_ids
    FROM public.profiles
    WHERE username IN ('supachat_bot', 'admin_dev')
       OR id::text IN ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002')
       OR username LIKE 'test_%'
       OR username LIKE 'bot_%';

    IF v_fake_ids IS NULL OR ARRAY_LENGTH(v_fake_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'status', 'success',
            'message', 'O''chiriladigan fake akkauntlar topilmadi.'
        );
    END IF;

    -- 2. Qo'ng'iroqlarni tozalash (agar calls jadvali mavjud bo'lsa)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'calls') THEN
        DELETE FROM public.calls 
        WHERE caller_id::text = ANY(v_fake_ids)
           OR receiver_id::text = ANY(v_fake_ids);
    END IF;

    -- 3. Xabarlarni tozalash
    WITH del_msgs AS (
        DELETE FROM public.messages 
        WHERE sender_id::text = ANY(v_fake_ids)
           OR chat_id::text = '00000000-0000-4000-a000-000000000010'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_messages FROM del_msgs;

    -- 4. Chat ishtirokchilarini tozalash
    WITH del_parts AS (
        DELETE FROM public.chat_participants 
        WHERE user_id::text = ANY(v_fake_ids)
           OR chat_id::text = '00000000-0000-4000-a000-000000000010'
        RETURNING chat_id
    )
    SELECT COUNT(*) INTO v_deleted_participants FROM del_parts;

    -- 5. Chatlarni tozalash
    WITH del_chats AS (
        DELETE FROM public.chats 
        WHERE id::text = '00000000-0000-4000-a000-000000000010'
           OR created_by::text = ANY(v_fake_ids)
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_chats FROM del_chats;

    -- 6. Qurilma tokenlarini tozalash
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_devices') THEN
        DELETE FROM public.user_devices 
        WHERE user_id::text = ANY(v_fake_ids);
    END IF;

    -- 7. Profillarni tozalash
    WITH del_profs AS (
        DELETE FROM public.profiles 
        WHERE id::text = ANY(v_fake_ids)
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_profiles FROM del_profs;

    RETURN jsonb_build_object(
        'status', 'success',
        'deleted_profiles_count', v_deleted_profiles,
        'deleted_messages_count', v_deleted_messages,
        'deleted_chats_count', v_deleted_chats
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ------------------------------------------------------------------------------
-- 2. TOZALASHNI AMALGA OSHIRISH (Run this to clean up immediately)
-- ------------------------------------------------------------------------------
SELECT public.cleanup_fake_accounts();


-- ------------------------------------------------------------------------------
-- 3. KELGUSIDA FAKE / INVALID USERNAME'LARNI TO'SISH TRIGGERI
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_username_validity()
RETURNS TRIGGER AS $$
BEGIN
    NEW.username := LOWER(TRIM(REPLACE(NEW.username, '@', '')));
    
    -- Rezerv qilingan tizim nomlariga ruxsat bermaslik
    IF NEW.username IN ('admin', 'bot', 'support', 'official', 'supachat', 'system', 'root') THEN
        RAISE EXCEPTION 'Ushbu username band qilingan tizim nomi hisoblanadi.';
    END IF;
    
    -- Kamida 3 ta belgi
    IF LENGTH(NEW.username) < 3 THEN
        RAISE EXCEPTION 'Username kamida 3 ta belgidan iborat bo''lishi shart.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_username_validity ON public.profiles;
CREATE TRIGGER trg_check_username_validity
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.check_username_validity();
