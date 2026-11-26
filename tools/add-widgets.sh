#!/bin/bash
# Adds four Android home-screen widgets to the generated Capacitor project.
# Run from the repo root after "npx cap add android". Exits non-zero on any problem so the workflow can fall back.
set -e
PKG=com.coldlogic.planner
J=android/app/src/main/java/com/coldlogic/planner
R=android/app/src/main/res
M=android/app/src/main/AndroidManifest.xml
[ -d "$J" ] || { echo "Java folder not found"; exit 1; }
ls $J/MainActivity.* >/dev/null
rm -f $J/MainActivity.kt
mkdir -p $R/layout $R/xml $R/drawable $R/values

cat > $J/MainActivity.java <<'EOF'
package com.coldlogic.planner;

import android.content.Intent;
import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(ColdWidgetPlugin.class);
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
    }
}
EOF

cat > $J/ColdWidgetPlugin.java <<'EOF'
package com.coldlogic.planner;

import android.content.Context;
import android.content.Intent;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "ColdWidget")
public class ColdWidgetPlugin extends Plugin {
    @PluginMethod
    public void update(PluginCall call) {
        String json = call.getString("json", "");
        Context c = getContext();
        c.getSharedPreferences("cold_widget", Context.MODE_PRIVATE).edit().putString("state", json).apply();
        ColdWidgets.refreshAll(c);
        call.resolve();
    }

    @PluginMethod
    public void launchTarget(PluginCall call) {
        JSObject o = new JSObject();
        Intent i = getActivity() == null ? null : getActivity().getIntent();
        if (i != null) {
            String go = i.getStringExtra("cl_go");
            if (go != null) {
                o.put("go", go);
                i.removeExtra("cl_go");
            }
        }
        call.resolve(o);
    }
}
EOF

cat > $J/WidgetViz.java <<'EOF'
package com.coldlogic.planner;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

/* Home-screen snapshots of the app's visualizers. Android widgets cannot animate, so each update paints one frame;
   the picture follows today's progress (rays grow, the terrain ridge moves) and drifts a little with the clock. */
public class WidgetViz {
    static int hsl(float h, float s, float l, int a) {
        float c = (1f - Math.abs(2f * l - 1f)) * s;
        float hp = (h % 360f + 360f) % 360f / 60f;
        float x = c * (1f - Math.abs(hp % 2f - 1f));
        float r = 0, g = 0, b = 0;
        if (hp < 1) { r = c; g = x; } else if (hp < 2) { r = x; g = c; } else if (hp < 3) { g = c; b = x; }
        else if (hp < 4) { g = x; b = c; } else if (hp < 5) { r = x; b = c; } else { r = c; b = x; }
        float m = l - c / 2f;
        return Color.argb(a, Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255));
    }

    static float hueAt(float x) {
        float u = (x + 1f) / 2f;
        float h = u < .5f ? 288f - u * 34f : 271f - (u - .5f) * 2f * 52f;
        if (u > .82f) h -= (u - .82f) / .18f * 22f;
        return h;
    }

    static float rnd(long[] sd) {
        sd[0] = (sd[0] * 16807L) % 2147483647L;
        return (sd[0] - 1) / 2147483646f;
    }

    static Bitmap draw(String style, int w, int h, int pct) {
        Bitmap b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
        if (style == null || style.equals("off")) return b;
        Canvas cv = new Canvas(b);
        float k = .6f + .4f * Math.min(100, Math.max(0, pct)) / 100f;
        float drift = (float) ((System.currentTimeMillis() / 60000L) % 360L);
        if (style.equals("terrain")) terrain(cv, w, h, pct, drift);
        else if (style.equals("ring")) ring(cv, w, h, k, drift);
        else if (style.equals("orb")) orb(cv, w, h, k, drift);
        else rays(cv, w, h, k, style.equals("orbital"));
        return b;
    }

    static float formation(int w, int h) {
        return Math.min(w, Math.max(h, w * .5f));
    }

    /* Icy aura / Orbital aura */
    static void rays(Canvas cv, int w, int h, float k, boolean orbital) {
        float S = formation(w, h), cx = w / 2f, cy = h / 2f, u = S / 1000f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setShader(new RadialGradient(cx, cy, S * .34f, 0xFF22164E, 0x00080618, Shader.TileMode.CLAMP));
        p.setAlpha(150);
        cv.drawCircle(cx, cy, S * .34f, p);
        p.setShader(null);
        if (!orbital) {
            float[][] sm = {{-.28f, .02f, 0}, {-.24f, .22f, 0}, {-.2f, -.24f, 0}, {.28f, -.02f, 1}, {.24f, .22f, 1}, {.2f, -.24f, 1}};
            for (float[] q : sm) {
                float x = cx + q[0] * S, y = cy + q[1] * S, r = S * .27f;
                int col = q[2] == 0 ? hsl(275f, .8f, .42f, 90) : hsl(218f, .85f, .45f, 90);
                p.setShader(new RadialGradient(x, y, r, col, col & 0x00FFFFFF, Shader.TileMode.CLAMP));
                cv.drawCircle(x, y, r, p);
            }
            p.setShader(null);
        }
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(u * 1.2f);
        p.setColor(hsl(262f, .9f, .75f, 80));
        cv.drawCircle(cx, cy, S * .305f, p);
        p.setStrokeWidth(u * .9f);
        p.setColor(hsl(262f, .9f, .75f, 45));
        cv.drawCircle(cx, cy, S * .345f, p);
        cv.drawCircle(cx, cy, S * .4f, p);
        long[] sd = {7};
        int n = orbital ? 340 : 300;
        Paint dot = new Paint(Paint.ANTI_ALIAS_FLAG);
        for (int i = 0; i < n; i++) {
            float r1 = rnd(sd), r2 = rnd(sd);
            double th = i * 2 * Math.PI / n;
            float cs = (float) Math.cos(th), sn = (float) Math.sin(th);
            float clus = .5f + .5f * (float) (Math.sin(th * 5.3 + 1.1) * Math.sin(th * 2.1 + .4));
            float nn = (float) Math.pow(.5f * r1 + .5f * clus, 1.7);
            float len = (.02f + .17f * nn) * (r2 > .93f ? 1.5f : 1f) * k * (orbital ? 1.12f : 1f);
            float a = (.3f + (r2 - .5f) * .07f) * S, e = a + len * S, m = a + len * S * .6f;
            float hh = hueAt(cs), l = .62f + (cs + 1f) / 2f * .22f;
            p.setStrokeWidth(u * (r1 < .6f ? .9f : r1 < .92f ? 1.3f : 2f));
            p.setColor(hsl(hh, 1f, l, 235));
            cv.drawLine(cx + cs * a, cy + sn * a, cx + cs * m, cy + sn * m, p);
            p.setColor(hsl(hh, 1f, l, 120));
            cv.drawLine(cx + cs * m, cy + sn * m, cx + cs * e, cy + sn * e, p);
            if (r2 < .62f) {
                dot.setColor(hsl(hh, 1f, Math.min(.95f, l + .14f), 220));
                cv.drawCircle(cx + cs * e, cy + sn * e, u * (1.2f + r1 * 1.6f), dot);
            }
        }
        cv.save();
        cv.rotate(orbital ? 9f : 6f, cx, cy);
        p.setShader(new LinearGradient(cx - S * .47f, 0, cx + S * .47f, 0,
            new int[]{hsl(294f, 1f, .68f, 255), hsl(262f, 1f, .76f, 255), hsl(232f, 1f, .82f, 255), hsl(208f, 1f, .84f, 255)},
            new float[]{0f, .45f, .55f, 1f}, Shader.TileMode.CLAMP));
        RectF o = new RectF(cx - S * .47f, cy - S * .085f, cx + S * .47f, cy + S * .085f);
        p.setStrokeWidth(u * 7f);
        p.setAlpha(26);
        cv.drawOval(o, p);
        p.setStrokeWidth(u * 2.4f);
        p.setAlpha(210);
        cv.drawOval(o, p);
        p.setShader(null);
        cv.restore();
        p.setStyle(Paint.Style.FILL);
        p.setShader(new RadialGradient(cx, cy, S * .1f, 0xFFFFFFFF, 0x00B49BFF, Shader.TileMode.CLAMP));
        cv.drawCircle(cx, cy, S * .1f, p);
        p.setShader(null);
        p.setColor(0x66FFFFFF);
        cv.drawRect(cx - S * .2f, cy - u * .5f, cx + S * .2f, cy + u * .5f, p);
    }

    /* Spike orb: rainbow 3D sphere */
    static void orb(Canvas cv, int w, int h, float k, float drift) {
        float S = formation(w, h), cx = w / 2f, cy = h / 2f, u = S / 1000f, R = S * .2f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStrokeCap(Paint.Cap.ROUND);
        double yaw = Math.toRadians(30 + drift * 2), pit = -.35;
        float cy2 = (float) Math.cos(yaw), sy = (float) Math.sin(yaw), cp = (float) Math.cos(pit), sp = (float) Math.sin(pit);
        int n = 520;
        p.setStyle(Paint.Style.STROKE);
        for (int pass = 0; pass < 2; pass++) {
            if (pass == 1) {
                p.setStyle(Paint.Style.FILL);
                p.setShader(new RadialGradient(cx - R * .35f, cy - R * .4f, R * 1.25f, 0xFF7C6CFF, 0xFF0B0820, Shader.TileMode.CLAMP));
                cv.drawCircle(cx, cy, R, p);
                p.setShader(null);
                p.setStyle(Paint.Style.STROKE);
            }
            for (int i = 0; i < n; i++) {
                float y = 1f - 2f * (i + .5f) / n, r = (float) Math.sqrt(1f - y * y), a = i * 2.399963f;
                float x = (float) Math.cos(a) * r, z = (float) Math.sin(a) * r;
                float x1 = x * cy2 + z * sy, z1 = -x * sy + z * cy2;
                float y1 = y * cp - z1 * sp, z2 = y * sp + z1 * cp;
                boolean front = z2 > 0;
                if ((pass == 0) == front) continue;
                float sd = (float) Math.abs(Math.sin(i * 12.9898));
                float len = R * (.18f + 1.25f * sd * sd) * k;
                float hue = (float) (((Math.atan2(z1, x1) / (2 * Math.PI) + .5) * 360 + y * 70 + 360) % 360);
                float bx = cx + x1 * R, by = cy - y1 * R, ex = cx + x1 * (R + len), ey = cy - y1 * (R + len);
                p.setStrokeWidth(u * (front ? 1.8f : 1.1f));
                p.setColor(hsl(hue, 1f, front ? .66f : .5f, front ? 235 : 110));
                cv.drawLine(bx, by, ex, ey, p);
            }
        }
        cv.save();
        cv.rotate(-14f, cx, cy);
        p.setShader(new LinearGradient(cx - S * .4f, 0, cx + S * .4f, 0,
            new int[]{hsl(300f, 1f, .7f, 255), hsl(190f, 1f, .75f, 255), hsl(60f, 1f, .7f, 255)}, null, Shader.TileMode.CLAMP));
        p.setStrokeWidth(u * 2f);
        p.setAlpha(210);
        cv.drawOval(new RectF(cx - S * .4f, cy - S * .1f, cx + S * .4f, cy + S * .1f), p);
        p.setShader(null);
        cv.restore();
    }

    /* Wave terrain: perspective grid, progress ridge at today's completion */
    static void terrain(Canvas cv, int w, int h, int pct, float drift) {
        int NX = 34, NY = 20;
        float AX = 1.08f, cA = (float) Math.cos(AX), sA = (float) Math.sin(AX), CAM = 4.9f;
        float Fx = w * 1.15f, Fy = h * 1.25f, cx = w / 2f, cy = h * .62f;
        float jm = Math.min(100, Math.max(0, pct)) / 100f * (NY - 1);
        float[][] X = new float[NY][NX], Y = new float[NY][NX];
        float flow = drift * .35f;
        for (int j = 0; j < NY; j++) {
            float y = (j / (float) (NY - 1) - .5f) * 5.6f, rj = j - jm;
            float ridge = .42f * (float) Math.exp(-(rj / 1.5f) * (rj / 1.5f));
            for (int i = 0; i < NX; i++) {
                float x = (i / (float) (NX - 1) - .5f) * 6.4f;
                float z = (.24f * (float) (Math.sin(x * 2.1 + flow * .7 + y * .6) * Math.cos(y * 1.7 - flow * .55))
                    + .1f * (float) (Math.sin(x * 4.3 - flow * 1.1) * Math.sin(y * 3.1 + flow * .8)) + ridge) * 2.6f;
                float q1 = y * cA - z * sA, q2 = y * sA + z * cA, s = 1f / (CAM + q1);
                X[j][i] = cx + x * Fx * s;
                Y[j][i] = cy - q2 * Fy * s;
            }
        }
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeCap(Paint.Cap.ROUND);
        float u = Math.max(1f, w / 390f);
        for (int j = 0; j < NY; j++) {
            boolean done = j <= jm;
            float near = 1f - j / (float) (NY - 1);
            Path path = new Path();
            path.moveTo(X[j][0], Y[j][0]);
            for (int i = 1; i < NX - 1; i++) path.quadTo(X[j][i], Y[j][i], (X[j][i] + X[j][i + 1]) / 2f, (Y[j][i] + Y[j][i + 1]) / 2f);
            path.lineTo(X[j][NX - 1], Y[j][NX - 1]);
            p.setStrokeWidth((done ? 1.5f : 1.1f) * u);
            p.setColor(done ? hsl(186f, 1f, .58f + near * .14f, (int) (255 * (.2f + .55f * near))) : hsl(264f, .55f, .46f + near * .1f, (int) (255 * (.12f + .35f * near))));
            cv.drawPath(path, p);
        }
        p.setStrokeWidth(1f * u);
        p.setColor(hsl(186f, .7f, .62f, 36));
        for (int i = 0; i < NX; i += 3) {
            Path dp = new Path();
            dp.moveTo(X[0][i], Y[0][i]);
            for (int j = 1; j < NY; j++) dp.lineTo(X[j][i], Y[j][i]);
            cv.drawPath(dp, p);
        }
        int jr = Math.min(NY - 1, Math.round(jm));
        Path rp = new Path();
        rp.moveTo(X[jr][0], Y[jr][0]);
        for (int i = 1; i < NX - 1; i++) rp.quadTo(X[jr][i], Y[jr][i], (X[jr][i] + X[jr][i + 1]) / 2f, (Y[jr][i] + Y[jr][i + 1]) / 2f);
        rp.lineTo(X[jr][NX - 1], Y[jr][NX - 1]);
        p.setStrokeWidth(5f * u);
        p.setColor(hsl(186f, 1f, .7f, 60));
        cv.drawPath(rp, p);
        p.setStrokeWidth(2.2f * u);
        p.setColor(hsl(186f, 1f, .86f, 240));
        cv.drawPath(rp, p);
    }

    /* 2D ring: the classic flat spectrum */
    static void ring(Canvas cv, int w, int h, float k, float drift) {
        float S = formation(w, h), cx = w / 2f, cy = h / 2f, u = S / 1000f;
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(u * 1.4f);
        p.setColor(hsl(262f, .9f, .75f, 90));
        cv.drawCircle(cx, cy, S * .27f, p);
        int n = 120;
        long[] sd = {(long) drift + 3};
        p.setStrokeWidth(u * 7f);
        for (int i = 0; i < n; i++) {
            double th = i * 2 * Math.PI / n;
            float cs = (float) Math.cos(th), sn = (float) Math.sin(th);
            float env = .5f + .5f * (float) Math.sin(th * 3 + drift * .1);
            float len = (.02f + .15f * rnd(sd) * env) * k;
            float a = S * .29f, e = a + len * S;
            p.setColor(hsl(hueAt(cs), 1f, .6f + (cs + 1f) / 2f * .2f, 235));
            cv.drawLine(cx + cs * a, cy + sn * a, cx + cs * e, cy + sn * e, p);
        }
    }
}
EOF

cat > $J/ColdWidgets.java <<'EOF'
package com.coldlogic.planner;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.os.Build;
import android.os.SystemClock;
import android.widget.RemoteViews;
import org.json.JSONObject;
import java.util.Calendar;

public class ColdWidgets {
    static JSONObject state(Context c) {
        try {
            return new JSONObject(c.getSharedPreferences("cold_widget", Context.MODE_PRIVATE).getString("state", "{}"));
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    static void refreshAll(Context c) {
        AppWidgetManager m = AppWidgetManager.getInstance(c);
        upd(c, m, ProgressWidget.class, 0);
        upd(c, m, NextWidget.class, 1);
        upd(c, m, ActionsWidget.class, 2);
        upd(c, m, FocusWidget.class, 3);
        upd(c, m, AuraWidget.class, 4);
    }

    static void upd(Context c, AppWidgetManager m, Class<?> k, int kind) {
        int[] ids = m.getAppWidgetIds(new ComponentName(c, k));
        if (ids == null || ids.length == 0) return;
        m.updateAppWidget(ids, build(c, kind));
    }

    static RemoteViews build(Context c, int kind) {
        if (kind == 0) return progress(c);
        if (kind == 1) return next(c);
        if (kind == 2) return actions(c);
        if (kind == 4) return auraView(c);
        return focus(c);
    }

    static PendingIntent open(Context c, String go, int code) {
        Intent i = new Intent(c, MainActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        if (go != null) i.putExtra("cl_go", go);
        return PendingIntent.getActivity(c, code, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static String t12(String hhmm) {
        try {
            String[] p = hhmm.split(":");
            int h = Integer.parseInt(p[0]);
            int m = Integer.parseInt(p[1]);
            return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
        } catch (Exception e) {
            return hhmm;
        }
    }

    static Bitmap ring(int pct) {
        int s = 200;
        Bitmap b = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888);
        Canvas cv = new Canvas(b);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(18f);
        p.setStrokeCap(Paint.Cap.ROUND);
        RectF r = new RectF(18f, 18f, s - 18f, s - 18f);
        p.setColor(0xFF23232F);
        cv.drawArc(r, 0f, 360f, false, p);
        if (pct > 0) {
            p.setColor(pct >= 80 ? 0xFF2DFFB4 : 0xFF22D3EE);
            cv.drawArc(r, -90f, 360f * Math.min(100, pct) / 100f, false, p);
        }
        return b;
    }

    static String style(JSONObject s, String key, String def) {
        JSONObject w = s.optJSONObject("wviz");
        return w == null ? def : w.optString(key, def);
    }

    static void viz(RemoteViews v, JSONObject s, String key, String def, int w, int h) {
        v.setImageViewBitmap(R.id.cl_viz, WidgetViz.draw(style(s, key, def), w, h, s.optInt("completionPct", 0)));
    }

    static RemoteViews progress(Context c) {
        JSONObject s = state(c);
        int pct = s.optInt("completionPct", 0);
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_progress);
        v.setImageViewBitmap(R.id.cl_ring, ring(pct));
        v.setTextViewText(R.id.cl_pct, pct + "%");
        v.setTextViewText(R.id.cl_sub, s.optInt("tasksDone", 0) + " of " + s.optInt("tasksTotal", 0) + " done");
        v.setTextViewText(R.id.cl_sub2, "Streak " + s.optInt("streak", 0) + "  ·  Lv " + s.optInt("level", 1));
        viz(v, s, "progress", "ring", 420, 420);
        v.setOnClickPendingIntent(R.id.cl_root, open(c, "day", 10));
        return v;
    }

    static RemoteViews next(Context c) {
        JSONObject s = state(c);
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_next);
        JSONObject a = s.optJSONObject("activeBlock");
        JSONObject n = s.optJSONObject("nextBlock");
        String label = "NEXT";
        String when = "";
        String name = "Nothing scheduled";
        if (a != null && !a.optBoolean("done", false)) {
            label = "NOW";
            name = a.optString("name", "");
            when = t12(a.optString("start", ""));
        } else if (n != null) {
            label = "NEXT";
            name = n.optString("name", "");
            when = t12(n.optString("start", ""));
        }
        v.setTextViewText(R.id.cl_label, label);
        v.setTextViewText(R.id.cl_when, when);
        v.setTextViewText(R.id.cl_name, name);
        v.setTextViewText(R.id.cl_left, s.optInt("tasksDone", 0) + "/" + s.optInt("tasksTotal", 0));
        viz(v, s, "next", "terrain", 640, 220);
        v.setOnClickPendingIntent(R.id.cl_root, open(c, "day", 11));
        return v;
    }

    static RemoteViews actions(Context c) {
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_actions);
        viz(v, state(c), "actions", "orbital", 640, 220);
        v.setOnClickPendingIntent(R.id.cl_a1, open(c, "day", 21));
        v.setOnClickPendingIntent(R.id.cl_a2, open(c, "workout", 22));
        v.setOnClickPendingIntent(R.id.cl_a3, open(c, "fuel", 23));
        v.setOnClickPendingIntent(R.id.cl_a4, open(c, "water", 24));
        return v;
    }

    static RemoteViews focus(Context c) {
        JSONObject s = state(c);
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_focus);
        double h = s.optInt("focusMin", 0) / 60.0;
        v.setTextViewText(R.id.cl_fh, String.format(java.util.Locale.US, "%.1f H", h));
        viz(v, s, "focus", "orb", 560, 220);
        String cut = s.optString("cutoff", "22:20");
        boolean on = s.optBoolean("sleepOn", true);
        v.setTextViewText(R.id.cl_cut, on ? "Cutoff " + t12(cut) : "Cutoff off");
        if (on && Build.VERSION.SDK_INT >= 24) {
            try {
                String[] p = cut.split(":");
                Calendar t = Calendar.getInstance();
                t.set(Calendar.HOUR_OF_DAY, Integer.parseInt(p[0]));
                t.set(Calendar.MINUTE, Integer.parseInt(p[1]));
                t.set(Calendar.SECOND, 0);
                t.set(Calendar.MILLISECOND, 0);
                if (t.getTimeInMillis() <= System.currentTimeMillis()) t.add(Calendar.DAY_OF_MONTH, 1);
                long base = SystemClock.elapsedRealtime() + (t.getTimeInMillis() - System.currentTimeMillis());
                v.setChronometerCountDown(R.id.cl_chr, true);
                v.setChronometer(R.id.cl_chr, base, null, true);
            } catch (Exception e) {
                v.setChronometer(R.id.cl_chr, SystemClock.elapsedRealtime(), null, false);
            }
        }
        v.setOnClickPendingIntent(R.id.cl_root, open(c, "day", 31));
        return v;
    }

    static RemoteViews auraView(Context c) {
        JSONObject s = state(c);
        int pct = s.optInt("completionPct", 0);
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_aura);
        viz(v, s, "aura", "aura", 520, 520);
        v.setTextViewText(R.id.cl_apct, pct + "%");
        v.setTextViewText(R.id.cl_asub, s.optInt("tasksDone", 0) + "/" + s.optInt("tasksTotal", 0) + " done  ·  Streak " + s.optInt("streak", 0));
        v.setOnClickPendingIntent(R.id.cl_root, open(c, "day", 41));
        return v;
    }
}
EOF

for K in "Progress:0" "Next:1" "Actions:2" "Focus:3" "Aura:4"; do
N=${K%%:*}; I=${K##*:}
cat > $J/${N}Widget.java <<EOF
package com.coldlogic.planner;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;

public class ${N}Widget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) {
            manager.updateAppWidget(id, ColdWidgets.build(context, $I));
        }
    }
}
EOF
done

cat > $R/drawable/cl_widget_bg.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#00000000" />
</shape>
EOF
cat > $R/drawable/cl_btn_bg.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#33000000" />
    <corners android:radius="14dp" />
</shape>
EOF

cat > $R/layout/cl_widget_progress.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <ImageView
        android:id="@+id/cl_viz"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:contentDescription="Visualizer"
        android:scaleType="centerCrop" />
    <LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="12dp">
    <ImageView
        android:id="@+id/cl_ring"
        android:layout_width="78dp"
        android:layout_height="78dp"
        android:contentDescription="Completion ring"
        android:scaleType="fitCenter" />
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_marginStart="10dp"
        android:layout_weight="1"
        android:orientation="vertical">
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_pct"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#F2F2F7"
            android:textSize="26sp"
            android:textStyle="bold" />
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_sub"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="12sp" />
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_sub2"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="12sp" />
    </LinearLayout>
</LinearLayout>
</FrameLayout>
EOF

cat > $R/layout/cl_widget_next.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <ImageView
        android:id="@+id/cl_viz"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:contentDescription="Visualizer"
        android:scaleType="centerCrop" />
    <LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="14dp">
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical">
        <LinearLayout
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:orientation="horizontal">
            <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
                android:id="@+id/cl_label"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#22D3EE"
                android:textSize="11sp"
                android:textStyle="bold" />
            <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
                android:id="@+id/cl_when"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp"
                android:textColor="#A0A0B2"
                android:textSize="11sp" />
        </LinearLayout>
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_name"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:ellipsize="end"
            android:maxLines="1"
            android:textColor="#F2F2F7"
            android:textSize="18sp"
            android:textStyle="bold" />
    </LinearLayout>
    <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
        android:id="@+id/cl_left"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="#A0A0B2"
        android:textSize="14sp" />
</LinearLayout>
</FrameLayout>
EOF

cat > $R/layout/cl_widget_actions.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <ImageView
        android:id="@+id/cl_viz"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:contentDescription="Visualizer"
        android:scaleType="centerCrop" />
    <LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="8dp">
    <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
        android:id="@+id/cl_a1"
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_margin="3dp"
        android:layout_weight="1"
        android:background="@drawable/cl_btn_bg"
        android:gravity="center"
        android:text="DAY"
        android:textColor="#F2F2F7"
        android:textSize="12sp"
        android:textStyle="bold" />
    <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
        android:id="@+id/cl_a2"
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_margin="3dp"
        android:layout_weight="1"
        android:background="@drawable/cl_btn_bg"
        android:gravity="center"
        android:text="WORK-OUT"
        android:textColor="#F2F2F7"
        android:textSize="12sp"
        android:textStyle="bold" />
    <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
        android:id="@+id/cl_a3"
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_margin="3dp"
        android:layout_weight="1"
        android:background="@drawable/cl_btn_bg"
        android:gravity="center"
        android:text="FUEL"
        android:textColor="#F2F2F7"
        android:textSize="12sp"
        android:textStyle="bold" />
    <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
        android:id="@+id/cl_a4"
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_margin="3dp"
        android:layout_weight="1"
        android:background="@drawable/cl_btn_bg"
        android:gravity="center"
        android:text="+250 ML"
        android:textColor="#22D3EE"
        android:textSize="12sp"
        android:textStyle="bold" />
</LinearLayout>
</FrameLayout>
EOF

cat > $R/layout/cl_widget_focus.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <ImageView
        android:id="@+id/cl_viz"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:contentDescription="Visualizer"
        android:scaleType="centerCrop" />
    <LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="14dp">
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical">
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="FOCUS TODAY"
            android:textColor="#A0A0B2"
            android:textSize="10sp"
            android:textStyle="bold" />
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_fh"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#F2F2F7"
            android:textSize="24sp"
            android:textStyle="bold" />
    </LinearLayout>
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:gravity="end"
        android:orientation="vertical">
        <TextView
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_cut"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="10sp"
            android:textStyle="bold" />
        <Chronometer
        android:shadowColor="#CC000000"
        android:shadowRadius="8"
            android:id="@+id/cl_chr"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#F59E0B"
            android:textSize="22sp"
            android:textStyle="bold" />
    </LinearLayout>
</LinearLayout>
</FrameLayout>
EOF

cat > $R/layout/cl_widget_aura.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/cl_widget_bg"
    android:padding="6dp">
    <ImageView
        android:id="@+id/cl_viz"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:contentDescription="Icy aura"
        android:scaleType="fitCenter" />
    <LinearLayout
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|start"
        android:layout_margin="8dp"
        android:orientation="vertical">
        <TextView
            android:id="@+id/cl_apct"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:shadowColor="#000000"
            android:shadowRadius="6"
            android:textColor="#F2F2F7"
            android:textSize="20sp"
            android:textStyle="bold" />
        <TextView
            android:id="@+id/cl_asub"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:shadowColor="#000000"
            android:shadowRadius="6"
            android:textColor="#C4C4D6"
            android:textSize="10sp" />
    </LinearLayout>
</FrameLayout>
EOF

for K in "progress:110:110:2:2" "next:250:55:4:1" "actions:250:55:4:1" "focus:180:55:3:1" "aura:180:180:3:3"; do
IFS=: read N W H TW TH <<< "$K"
cat > $R/xml/cl_widget_$N.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/cl_w_$N"
    android:initialLayout="@layout/cl_widget_$N"
    android:minHeight="${H}dp"
    android:minWidth="${W}dp"
    android:resizeMode="horizontal|vertical"
    android:targetCellHeight="$TH"
    android:targetCellWidth="$TW"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
EOF
done

cat > $R/values/cl_widgets.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="cl_w_progress">Today progress ring, streak and level</string>
    <string name="cl_w_next">The current or next block of your day</string>
    <string name="cl_w_actions">Quick buttons: Day, Work-out, Fuel, +250 ml water</string>
    <string name="cl_w_aura">Icy aura: rays that grow with your day, plus completion and streak</string>
    <string name="cl_w_focus">Focus hours today and a countdown to your sleep cutoff</string>
</resources>
EOF

python3 - <<'PY'
m='android/app/src/main/AndroidManifest.xml'
s=open(m,encoding='utf-8').read()
if 'ProgressWidget' not in s:
    r=''
    for n,x in (('ProgressWidget','progress'),('NextWidget','next'),('ActionsWidget','actions'),('FocusWidget','focus'),('AuraWidget','aura')):
        r+=('    <receiver android:name=".%s" android:exported="true">\n'
            '        <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>\n'
            '        <meta-data android:name="android.appwidget.provider" android:resource="@xml/cl_widget_%s" />\n'
            '    </receiver>\n')%(n,x)
    assert s.count('</application>')==1
    s=s.replace('</application>',r+'</application>')
    open(m,'w',encoding='utf-8').write(s)
PY
touch /tmp/widgets_on
echo "Widgets added"
