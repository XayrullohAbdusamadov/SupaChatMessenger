# SupaChat Messenger — Supabase Backend & Storage Qo'llanmasi

Ushbu katalog SupaChat Messenger loyihasining backend, ma'lumotlar bazasi, RLS xavfsizlik qoidalari, Realtime sozlamalari, Storage chelaklari va Edge Functions fayllarini o'z ichiga oladi.

---

## 📁 Fayllar Strukturasi

```
supabase/
├── config.toml                              # Supabase CLI mahalliy konfiguratsiyasi
├── seed.sql                                 # Boshlang'ich demo profillar, chatlar va xabarlar
├── functions/
│   └── send-push-notification/
│       └── index.ts                         # FCM Push Bildirishnomalari uchun Edge Function (Deno/TS)
└── README.md                                # Ushbu qo'llanma

Ildizda:
└── supabase_schema.sql                      # Asosiy DB jadvallari, RLS va Realtime sxemasi
```

---

## 🛠️ O'rnatish va Ishga Tushirish (3 xil usul)

### 1-Usul: Supabase Cloud (Dashboard) orqali (Tavsiya etiladi)

1. [supabase.com](https://supabase.com) ga kiring va yangi bepul loyiha yarating.
2. **SQL Editor** bo'limiga o'ting va [supabase_schema.sql](file:///d:/Loyihalar/SupaChatMessenger/supabase_schema.sql) fayli ichidagi SQL kodini nusxalab ishga tushiring (**Run**).
3. (Ixtiyoriy) Demo ma'lumotlarni kiritish uchun [seed.sql](file:///d:/Loyihalar/SupaChatMessenger/supabase/seed.sql) faylini ham SQL Editorda ishga tushiring.
4. **Storage** bo'limiga o'ting va 2 ta ommaviy (Public) bucket yarating:
   - `avatars`
   - `chat-attachments`
5. **Project Settings -> API** bo'limidan **Project URL** va **anon public** kalitini oling.
6. SupaChat Messenger ilovasining **Profile -> Supabase Sozlamalari** oynasiga kiritib **Ulash** tugmasini bosing!

---

### 2-Usul: Supabase CLI (Mahalliy Docker) orqali

```bash
# Supabase CLI orqali mahalliy serverni ishga tushirish
supabase start

# Barcha migratsiyalar va seed ma'lumotlarni yuklash
supabase db reset
```

---

### 3-Usul: Supabase Edge Functions ni nashr qilish (FCM Push Notifications)

```bash
supabase functions deploy send-push-notification --no-verify-jwt
```
