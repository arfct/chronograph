# R8 full mode strips constructors that WorkManager and Room only reach via
# reflection. Glance runs every widget render through a WorkManager session,
# so a minified build fails at launch (WorkDatabase_Impl) and then renders
# "Can't load widget" (InputMerger, workers) without these.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.InputMerger { <init>(); }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
