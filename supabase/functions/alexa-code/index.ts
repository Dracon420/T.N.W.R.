// Gives the app a 6-digit code to say to the Alexa skill. Valid 10 minutes.
// Self-contained so it can be pasted into the Supabase dashboard editor.
import { createClient, type User } from "jsr:@supabase/supabase-js@2";

/** Server key: SUPABASE_SECRET_KEYS on new projects, service_role on older ones. */
function serverKey(): string {
  const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  return keys.default ?? Object.values(keys)[0] ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
}
/** Server-side client: bypasses row-level security. */
export const admin = createClient(Deno.env.get("SUPABASE_URL")!, serverKey());

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
  const user = await appUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  // One live code per install.
  await admin.from("alexa_pair_codes").delete().eq("app_user", user.id);

  for (let attempt = 0; attempt < 5; attempt++) {
    // No leading zero: Alexa hears "042..." as 42.
    const n = crypto.getRandomValues(new Uint32Array(1))[0];
    const code = String(100000 + (n % 900000));
    const { error } = await admin.from("alexa_pair_codes").insert({
      code,
      app_user: user.id,
      expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
    });
    if (!error) return json({ code, expiresInMinutes: 10 });
  }
  return json({ error: "could not create a code, try again" }, 500);
});
