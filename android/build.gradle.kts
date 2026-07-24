allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Les plugins Flutter (home_widget notamment) compilent en JVM 1.8 par défaut,
// alors que androidx.glance 1.1.1 (forcé dans app/build.gradle.kts) est du
// bytecode JVM 11 → "Cannot inline bytecode built with JVM target 11 into
// bytecode that is being built with JVM target 1.8".
// On aligne tous les sous-projets sur JVM 11 (Kotlin ET Java, sinon le
// validateur Kotlin échoue sur "Inconsistent JVM-target compatibility").
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    // Le réglage doit passer par l'extension Android (AGP écrase les valeurs
    // posées directement sur les tâches JavaCompile). Seul :app est déjà
    // évalué à ce stade (evaluationDependsOn ci-dessus) et il est déjà en
    // JVM 11 avec ses options finalisées — on le saute.
    if (!state.executed) {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileOptions
                ?.apply {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
