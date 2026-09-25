// Called by the Alexa skill (not the app) when the user says their code.
// Deploy with JWT verification OFF; it's protected by ALEXA_PAIR_SECRET,
// which must match PAIR_SECRET in alexa/lambda/config.js.
// Self-contained so it can be pasted into the Supabase dashboard editor.
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

/** Service-role client: bypasses row-level security, server side only. */
export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** The signed-in (anonymous) app user making the request, or null. */
export async function appUser(req: Request): Promise<User | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user;
}


Deno.serve(async (req) => {
  const secret = Deno.env.get("ALEXA_PAIR_SECRET");
  if (!secret || req.headers.get("x-pair-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }
  const { code, alexaUserId } = await req.json();
  if (!code || !alexaUserId) return json({ error: "missing code or user" }, 400);

  const now = new Date().toISOString();
  const { data: row } = await admin
    .from("alexa_pair_codes")
    .select("code, app_user")
    .eq("code", String(code))
    .gt("expires_at", now)
    .maybeSingle();
  if (!row) return json({ ok: false, reason: "bad_code" }, 404);

  await admin.from("alexa_links").upsert({
    app_user: row.app_user,
    alexa_user_id: alexaUserId,
    linked_at: now,
  });
  await admin.from("alexa_pair_codes").delete().eq("code", row.code);
  return json({ ok: true });
});
