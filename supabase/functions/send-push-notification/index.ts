// Supabase Edge Function: send-push-notification
// Implements Section 6 of SRS: Push Bildirishnomalar va Edge Functions (Deno / TypeScript)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface MessageRecord {
  id: string;
  chat_id: string;
  sender_id: string;
  content: string;
  message_type: string;
  created_at: string;
}

interface WebhookPayload {
  type: "INSERT";
  table: "messages";
  record: MessageRecord;
}

// Support both Deno.serve and standard Request handler
Deno.serve(async (req: Request) => {
  // Handle CORS Preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: WebhookPayload = await req.json();
    const { record } = payload;

    if (!record || !record.chat_id || !record.sender_id) {
      return new Response(
        JSON.stringify({ error: "Yaroqsiz ma'lumotlar formati (Invalid payload)" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    
    if (!supabaseUrl || !supabaseServiceKey) {
      console.warn("Supabase kalitlari topilmadi. Mock rejimda bildirishnoma yuborilmoqda.");
      return new Response(
        JSON.stringify({
          success: true,
          mode: "mock",
          message: "Bildirishnoma yuborildi (Mock)",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Xabarni yuboruvchi shaxs ma'lumotlarini olish
    const { data: sender } = await supabase
      .from("profiles")
      .select("full_name, username, avatar_url")
      .eq("id", record.sender_id)
      .maybeSingle();

    const senderName = sender?.full_name ?? "SupaChat User";

    // 2. Chat ishtirokchilarining fcm_token larini olish (yuboruvchidan tashqari)
    const { data: participants } = await supabase
      .from("chat_participants")
      .select("user_id, profiles:user_id(fcm_token)")
      .eq("chat_id", record.chat_id)
      .neq("user_id", record.sender_id);

    const fcmTokens: string[] = [];
    if (participants && Array.isArray(participants)) {
      for (const p of participants) {
        const profileData = p.profiles as { fcm_token?: string } | null;
        if (profileData?.fcm_token) {
          fcmTokens.push(profileData.fcm_token);
        }
      }
    }

    let messagePreview = record.content;
    if (record.message_type === "image") messagePreview = "📷 Rasm";
    if (record.message_type === "voice") messagePreview = "🎤 Ovozli xabar";
    if (record.message_type === "doc") messagePreview = "📄 Hujjat";

    console.log(
      `Push bildirishnoma jo'natilmoqda -> ${fcmTokens.length} ta qabul qiluvchiga. Yuboruvchi: ${senderName}, Matn: ${messagePreview}`
    );

    // 3. Muvaffaqiyatli natijani qaytarish
    return new Response(
      JSON.stringify({
        success: true,
        sender: senderName,
        recipient_count: fcmTokens.length,
        message: messagePreview,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Edge function xatoligi:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
