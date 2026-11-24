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
            String ap = h >= 12 ? "PM" : "AM";
            int h12 = (h % 12 == 0) ? 12 : (h % 12);
            return h12 + ":" + (m < 10 ? "0" : "") + m + " " + ap;
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

    static RemoteViews progress(Context c) {
        JSONObject s = state(c);
        int pct = s.optInt("completionPct", 0);
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_progress);
        v.setImageViewBitmap(R.id.cl_ring, ring(pct));
        v.setTextViewText(R.id.cl_pct, pct + "%");
        v.setTextViewText(R.id.cl_sub, s.optInt("tasksDone", 0) + " of " + s.optInt("tasksTotal", 0) + " done");
        v.setTextViewText(R.id.cl_sub2, "Streak " + s.optInt("streak", 0) + "  ·  Lv " + s.optInt("level", 1));
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
        v.setOnClickPendingIntent(R.id.cl_root, open(c, "day", 11));
        return v;
    }

    static RemoteViews actions(Context c) {
        RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.cl_widget_actions);
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
}
EOF

for K in "Progress:0" "Next:1" "Actions:2" "Focus:3"; do
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
    <solid android:color="#F20A0A10" />
    <corners android:radius="22dp" />
    <stroke android:width="1dp" android:color="#33FFFFFF" />
</shape>
EOF
cat > $R/drawable/cl_btn_bg.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#1FFFFFFF" />
    <corners android:radius="14dp" />
</shape>
EOF

cat > $R/layout/cl_widget_progress.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/cl_widget_bg"
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
            android:id="@+id/cl_pct"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#F2F2F7"
            android:textSize="26sp"
            android:textStyle="bold" />
        <TextView
            android:id="@+id/cl_sub"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="12sp" />
        <TextView
            android:id="@+id/cl_sub2"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="12sp" />
    </LinearLayout>
</LinearLayout>
EOF

cat > $R/layout/cl_widget_next.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/cl_widget_bg"
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
                android:id="@+id/cl_label"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#22D3EE"
                android:textSize="11sp"
                android:textStyle="bold" />
            <TextView
                android:id="@+id/cl_when"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="8dp"
                android:textColor="#A0A0B2"
                android:textSize="11sp" />
        </LinearLayout>
        <TextView
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
        android:id="@+id/cl_left"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="#A0A0B2"
        android:textSize="14sp" />
</LinearLayout>
EOF

cat > $R/layout/cl_widget_actions.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/cl_widget_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="8dp">
    <TextView
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
EOF

cat > $R/layout/cl_widget_focus.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/cl_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/cl_widget_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="14dp">
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical">
        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="FOCUS TODAY"
            android:textColor="#A0A0B2"
            android:textSize="10sp"
            android:textStyle="bold" />
        <TextView
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
            android:id="@+id/cl_cut"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#A0A0B2"
            android:textSize="10sp"
            android:textStyle="bold" />
        <Chronometer
            android:id="@+id/cl_chr"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#F59E0B"
            android:textSize="22sp"
            android:textStyle="bold" />
    </LinearLayout>
</LinearLayout>
EOF

for K in "progress:110:110:2:2" "next:250:55:4:1" "actions:250:55:4:1" "focus:180:55:3:1"; do
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
    <string name="cl_w_focus">Focus hours today and a countdown to your sleep cutoff</string>
</resources>
EOF

python3 - <<'PY'
m='android/app/src/main/AndroidManifest.xml'
s=open(m,encoding='utf-8').read()
if 'ProgressWidget' not in s:
    r=''
    for n,x in (('ProgressWidget','progress'),('NextWidget','next'),('ActionsWidget','actions'),('FocusWidget','focus')):
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
