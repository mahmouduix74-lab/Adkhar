# flutter_local_notifications keeps its scheduled-notification models through
# Gson-style reflection; R8 would otherwise strip them and reminders would
# silently stop firing after a reboot.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.dexterous.**
