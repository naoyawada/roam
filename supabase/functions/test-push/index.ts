// test-push: Send a silent push to a specific device for debugging.
// Called from the iOS app's Debug settings or manually via curl.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadAPNsConfig, sendSilentPush } from "../_shared/apns.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { device_id } = await req.json();
    if (!device_id) {
      return Response.json({ error: "device_id required" }, { status: 400 });
    }

    const config = loadAPNsConfig();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Look up the device token
    const { data: device, error } = await supabase
      .from("device_tokens")
      .select("device_id, token")
      .eq("device_id", device_id)
      .single();

    if (error || !device) {
      return Response.json(
        { error: "Device not found", device_id },
        { status: 404 }
      );
    }

    const result = await sendSilentPush(device.token, device.device_id, config, { test: 1 });

    // Log to push_log
    await supabase.from("push_log").insert({
      device_id: device.device_id,
      status: result.status === 200 ? "sent" : "failed",
      apns_response: {
        status: result.status,
        apnsId: result.apnsId,
        reason: result.reason,
      },
    });

    return Response.json(result);
  } catch (err) {
    console.error("test-push error:", err);
    return Response.json({ error: String(err) }, { status: 500 });
  }
});
