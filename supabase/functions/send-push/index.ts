// send-push: Query devices whose local time matches their capture schedule
// and send silent APNs push. Called hourly by pg_cron.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadAPNsConfig, sendSilentPush } from "../_shared/apns.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface Device {
  device_id: string;
  token: string;
  timezone: string;
  primary_hour: number;
  primary_minute: number;
  retry_hour: number;
  retry_minute: number;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const config = loadAPNsConfig();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch all registered devices with their schedule
    const { data: devices, error } = await supabase
      .from("device_tokens")
      .select("device_id, token, timezone, primary_hour, primary_minute, retry_hour, retry_minute");

    if (error) throw error;
    if (!devices || devices.length === 0) {
      return Response.json({ message: "No devices registered", sent: 0 });
    }

    // Filter to devices where local time matches their primary or retry hour
    const now = new Date();
    const targetDevices = (devices as Device[]).filter((d) => {
      try {
        const localHour = parseInt(
          new Intl.DateTimeFormat("en-US", {
            timeZone: d.timezone,
            hour: "numeric",
            hour12: false,
          }).format(now)
        );
        const localMinute = parseInt(
          new Intl.DateTimeFormat("en-US", {
            timeZone: d.timezone,
            minute: "numeric",
          }).format(now)
        );
        const matchesPrimary = localHour === d.primary_hour && localMinute === d.primary_minute;
        const matchesRetry = localHour === d.retry_hour && localMinute === d.retry_minute;
        return matchesPrimary || matchesRetry;
      } catch {
        return false;
      }
    });

    if (targetDevices.length === 0) {
      return Response.json({
        message: "No devices in their capture window",
        total: devices.length,
        sent: 0,
      });
    }

    // Stale token reasons that mean the device should be removed
    const staleReasons = new Set(["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"]);

    // Send push to each target device
    const results = await Promise.allSettled(
      targetDevices.map(async (d) => {
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

        // Clean up stale device tokens
        if (result.reason && staleReasons.has(result.reason)) {
          await supabase.from("device_tokens").delete().eq("device_id", d.device_id);
          console.log(`Removed stale device ${d.device_id}: ${result.reason}`);
        }

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
