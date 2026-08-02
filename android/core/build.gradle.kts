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
    // Shared cross-platform inputs live at the repo root / in apple/;
    // resolved here so tests never hardcode machine paths.
    systemProperty("chronograph.fixtures", rootDir.parentFile.resolve("fixtures").absolutePath)
    systemProperty("chronograph.cmudict", rootDir.parentFile.resolve("apple/Extensions/cmudict-ipa.txt").absolutePath)
}
