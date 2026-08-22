package com.cyanweather.app;

import android.content.Intent;
import android.provider.Settings;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "LocationSettings")
public class LocationSettingsPlugin extends Plugin {
    @PluginMethod
    public void open(PluginCall call) {
        try {
            getActivity().startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
            call.resolve();
        } catch (Exception exception) {
            call.reject("无法打开系统定位设置", exception);
        }
    }
}
