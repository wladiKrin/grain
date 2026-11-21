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

// Lint's own parser crashes on file_selector_android's sources under the
// JDK 17 toolchain (NoSuchMethodError List.removeLast); the plugins' vital
// lint adds nothing to a release build, the app's own lint still runs.
subprojects {
    if (project.name != "app") {
        tasks.configureEach {
            if (name.startsWith("lintVital")) enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
