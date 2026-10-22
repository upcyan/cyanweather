# 说明：当前 release 已关闭 R8（build.gradle: minifyEnabled false），本文件
# 暂未生效。保留是因为开启 minify 时 shared_preferences 2.5.x 的 JNIgen
# 会连续踩 NoSuchMethodError / ClassNotFoundException（Continuation、
# CoroutineSingletons、kotlin.Result 等只在 JNI 侧按名字查找）。
# 若重新开启 minify，请在 release.proguardFiles 中引用本文件，并完整回归
# 冷启动到首页。
#
# shared_preferences 2.5.x 走 JNIgen（dartjni）绑定：Dart 侧按 Java 原名
# 查找 SharedPreferencesApiRegistrar.getAll 等方法。R8 默认会删除/重命名
# 这些"Java 侧看似无人调用"的成员，运行时就会抛：
#   NoSuchMethodError: no non-static method "...SharedPreferencesApiRegistrar;.getAll(...)"
# 因此整包保留该插件与 JNI 桥接类。
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keepclassmembers class com.github.dart_lang.jni.** { *; }

# 关键：Registrar 的 suspend 方法描述符里带 kotlin.coroutines.Continuation。
# R8 full mode 会把它 repackage 成 e1.c，描述符随之改写；Dart JNI 按原名
# 查方法就会 NoSuchMethodError。必须保住 Continuation 的原名。
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.CoroutineContext { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep class kotlin.coroutines.jvm.internal.** { *; }
