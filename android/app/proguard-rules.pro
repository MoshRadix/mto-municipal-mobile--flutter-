# WorkManager creates this generated Room database through reflection.
# Keep its no-argument constructor available in optimized release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
