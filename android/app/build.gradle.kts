import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A assinatura de release não tem plano B. Se o key.properties faltar, o build
// para aqui: cair na chave de debug produziria um artefato que o Google Play
// rejeita, e a falha só apareceria no envio.
val arquivoDeAssinatura = rootProject.file("key.properties")
if (!arquivoDeAssinatura.exists()) {
    throw GradleException(
        "android/key.properties não encontrado. A assinatura de release exige " +
            "esse arquivo e a upload keystore (android/upload-keystore.jks). " +
            "Nenhum dos dois é versionado — gere-os localmente. " +
            "Assinar com a chave de debug não é alternativa aceita aqui.",
    )
}

val dadosDeAssinatura = Properties()
FileInputStream(arquivoDeAssinatura).use { dadosDeAssinatura.load(it) }

for (chave in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    if (dadosDeAssinatura.getProperty(chave).isNullOrBlank()) {
        throw GradleException("android/key.properties está sem a chave '$chave'.")
    }
}

// storeFile é resolvido a partir de android/app/, que é o diretório deste
// script — por isso o "../" do key.properties chega em android/.
val arquivoDaKeystore = file(dadosDeAssinatura.getProperty("storeFile"))
if (!arquivoDaKeystore.exists()) {
    throw GradleException(
        "Keystore não encontrada em ${arquivoDaKeystore.absolutePath}, " +
            "caminho vindo de storeFile no android/key.properties. " +
            "Gere a upload keystore antes de compilar o release.",
    )
}

android {
    namespace = "com.rodrigons.minhadegestacao"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rodrigons.minhadegestacao"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = arquivoDaKeystore
            storePassword = dadosDeAssinatura.getProperty("storePassword")
            keyAlias = dadosDeAssinatura.getProperty("keyAlias")
            keyPassword = dadosDeAssinatura.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
