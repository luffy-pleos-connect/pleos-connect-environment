plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "ai.pleos.sample.hello"
    compileSdk = 34

    defaultConfig {
        applicationId = "ai.pleos.sample.hello"
        // Pleos: 차량 보안(서명 키 rotation / lineage) 때문에 minSdk 28 이상 필수
        minSdk = 28
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // config/versions.env 의 PLEOS_VEHICLE_SDK_VERSION 과 맞춰 주세요.
    implementation("ai.pleos.playground:Vehicle:2.3.2")
}
