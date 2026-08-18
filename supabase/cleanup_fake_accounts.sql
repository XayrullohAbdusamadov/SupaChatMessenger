-- ==============================================================================
-- PART 1: SUPACHAT MESSENGER - FAKE / BOT / SPAM ACCOUNTS CLEANUP SCRIPT
-- ==============================================================================
-- INSTRUCTIONS:
-- 1. Run STEP 1 first (Dry-Run / Preview) to inspect matching fake accounts.
-- 2. Once verified, run STEP 2 in Supabase SQL Editor to safely delete them.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- STEP 1: DRY-RUN PREVIEW (Review accounts before deleting)
-- ------------------------------------------------------------------------------
SELECT 
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.created_at,
    (SELECT COUNT(*) FROM public.messages m WHERE m.sender_id::text = p.id::text) AS messages_sent,
    CASE 
        WHEN p.username IN ('supachat_bot', 'admin_dev') THEN 'Tizim bot/demo akkaunti'
        WHEN p.id::text IN ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002') THEN 'Tizim demo UUID'
        WHEN p.username LIKE 'test_%' OR p.username LIKE 'bot_%' OR p.username LIKE 'user_%' THEN 'Shubhali username pattern'
        WHEN (p.full_name IS NULL OR p.full_name = '') AND p.avatar_url IS NULL THEN 'To''ldirilmagan profil'
        ELSE 'Boshqa'
    END AS aniqlash_sababi
FROM public.profiles p
WHERE p.username IN ('supachat_bot', 'admin_dev')
   OR p.id::text IN ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002')
   OR p.username LIKE 'test_%'
   OR p.username LIKE 'bot_%'
ORDER BY p.created_at DESC;


-- ------------------------------------------------------------------------------
-- STEP 2: SAFE TRANSACTIONAL DELETION (CASCADE CLEANUP)
-- ------------------------------------------------------------------------------
BEGIN;

-- 1. Vaqtinchalik o'chirilishi kerak bo'lgan akkauntlar ID jadvali
CREATE TEMP TABLE temp_fake_user_ids AS
SELECT id::text AS id_str FROM public.profiles
WHERE username IN ('supachat_bot', 'admin_dev')
   OR id::text IN ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002')
   OR username LIKE 'test_%'
   OR username LIKE 'bot_%';

-- 2. Bot/Fake akkauntlarga tegishli qo'ng'iroqlarni tozalash (agar calls jadvali mavjud bo'lsa)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'calls' AND table_schema = 'public') THEN
        DELETE FROM public.calls 
        WHERE caller_id::text IN (SELECT id_str FROM temp_fake_user_ids)
           OR receiver_id::text IN (SELECT id_str FROM temp_fake_user_ids);
    END IF;
END $$;

-- 3. Bot/Fake akkauntlar yuborgan yoki qabul qilgan xabarlarni tozalash
DELETE FROM public.messages 
WHERE sender_id::text IN (SELECT id_str FROM temp_fake_user_ids)
   OR chat_id::text = '00000000-0000-4000-a000-000000000010';

-- 4. Demo umumiy chat va bot ishtirokchilarini tozalash
DELETE FROM public.chat_participants 
WHERE user_id::text IN (SELECT id_str FROM temp_fake_user_ids)
   OR chat_id::text = '00000000-0000-4000-a000-000000000010';

DELETE FROM public.chats 
WHERE id::text = '00000000-0000-4000-a000-000000000010'
   OR created_by::text IN (SELECT id_str FROM temp_fake_user_ids);

-- 5. Qurilma tokenlari va statuslarini tozalash
DELETE FROM public.user_devices 
WHERE user_id::text IN (SELECT id_str FROM temp_fake_user_ids);

-- 6. Bot/Fake profillarni o'chirish
DELETE FROM public.profiles 
WHERE id::text IN (SELECT id_str FROM temp_fake_user_ids);

-- 7. auth.users dan ham tegishli UUID larni tozalash (agar auth jadvallarida mavjud bo'lsa)
DELETE FROM auth.users 
WHERE id::text IN (SELECT id_str FROM temp_fake_user_ids);

DROP TABLE IF EXISTS temp_fake_user_ids;

COMMIT;


-- ------------------------------------------------------------------------------
-- STEP 3: KELGUSIDA FAKE/SPAM AKKAUNTLAR OLDINI OLISH BO'YICHA TAVSIYALAR
-- ------------------------------------------------------------------------------
-- 1. Email tasdiqlashni majburiy qilish:
--    Supabase Dashboard -> Authentication -> Providers -> Email -> "Confirm email" ni yoqing.
--
-- 2. Cloudflare Turnstile yoki reCAPTCHA v3 qo'shish:
--    Supabase Dashboard -> Authentication -> Bot Detection -> Turnstile ni yoqing.
--
-- 3. Username validatsiya triggeri (zaxiralangan so'zlardan saqlash):
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
