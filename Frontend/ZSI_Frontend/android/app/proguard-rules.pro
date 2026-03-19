# General TensorFlow Lite rule
-keep class org.tensorflow.lite.** { *; }

# Keep the GPU delegate and its options
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep underlying EGL classes that the GPU delegate might use
-keep class javax.microedition.khronos.egl.** { *; }
-keep class javax.microedition.khronos.opengles.** { *; }

# Keep Flutter native methods
-keepclasseswithmembernames class ** {
    native <methods>;
}

# Keep custom application classes
-keep class com.example.zsi_app.** { *; }

# Optimization flags for performance
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose
-dontwarn

# Remove logging in release builds (optimization)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
