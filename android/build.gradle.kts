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
    // 👇 CHANGE THIS LINE from "8.0.2" to "8.7.0"
    id("com.android.application") version "8.7.0" apply false

    // You might need to update Kotlin later, but try keeping this for now:
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false

    // This line is fine:
    id("com.google.gms.google-services") version "4.3.15" apply false
}