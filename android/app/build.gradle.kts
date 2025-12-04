plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // [중요] 구글 서비스 플러그인 적용
    id("com.google.gms.google-services")
}

android {
    namespace = "com.zonber.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.zonber.game"
        // [중요] 파이어베이스 최소 요구 버전 21로 변경
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // [추가 1] 이거 꼭 true로 해주세요
        multiDexEnabled = true 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // [추가 2] 멀티덱스 라이브러리
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
