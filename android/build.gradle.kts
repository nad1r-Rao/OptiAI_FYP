allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: standard clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {

    id("com.android.application") version "8.0.2" apply false
    id("org.jetbrains.kotlin.android") version "1.8.21" apply false

    // ✅ Add this line:
    id("com.google.gms.google-services") version "4.3.15" apply false
}
