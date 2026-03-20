// send-push: Query devices whose local time is 2 AM and send silent APNs push.
// Designed to be called hourly by pg_cron or an external scheduler.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadAPNsConfig, sendSilentPush } from "../_shared/apns.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const config = loadAPNsConfig();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch all registered devices
    const { data: devices, error } = await supabase
      .from("device_tokens")
      .select("device_id, token, timezone");

    if (error) throw error;
    if (!devices || devices.length === 0) {
      return Response.json({ message: "No devices registered", sent: 0 });
    }

    // Filter to devices where local time is in the 2 AM hour
    const now = new Date();
    const targetDevices = devices.filter((d: { timezone: string }) => {
      try {
        const localHour = parseInt(
          new Intl.DateTimeFormat("en-US", {
            timeZone: d.timezone,
            hour: "numeric",
            hour12: false,
          }).format(now)
        );
        return localHour === 2;
      } catch {
        return false;
      }
    });

    if (targetDevices.length === 0) {
      return Response.json({
        message: "No devices in the 2 AM window",
        total: devices.length,
        sent: 0,
      });
    }

    // Send push to each target device
    const results = await Promise.allSettled(
      targetDevices.map(async (d: { device_id: string; token: string }) => {
        const result = await sendSilentPush(d.token, d.device_id, config);

        // Log to push_log table
        await supabase.from("push_log").insert({
          device_id: d.device_id,
          status: result.status === 200 ? "sent" : "failed",
          apns_response: {
            status: result.status,
            apnsId: result.apnsId,
            reason: result.reason,
          },
        });

        return result;
      })
    );

    const sent = results.filter(
      (r) => r.status === "fulfilled" && r.value.status === 200
    ).length;

    return Response.json({
      total: devices.length,
      targeted: targetDevices.length,
      sent,
      results: results.map((r) =>
        r.status === "fulfilled" ? r.value : { error: String(r.reason) }
      ),
    });
  } catch (err) {
    console.error("send-push error:", err);
    return Response.json({ error: String(err) }, { status: 500 });
  }
});
