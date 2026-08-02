plugins {
    alias(libs.plugins.kotlin.jvm)
}

// Pure Kotlin JVM: row building, config, metrics, obfuscation, note parsing.
// No Android dependencies so everything here is testable without an emulator.
kotlin {
    jvmToolchain(21)
}

dependencies {
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.withType<Test> {
    useJUnitPlatform()
}
