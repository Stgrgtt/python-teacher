// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PythonTeacher",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PythonTeacherCore", targets: ["PythonTeacherCore"]),
        .executable(name: "PythonTeacher", targets: ["PythonTeacherApp"])
    ],
    targets: [
        .target(name: "PythonTeacherCore"),
        .executableTarget(name: "PythonTeacherApp", dependencies: ["PythonTeacherCore"]),
        .testTarget(name: "PythonTeacherCoreTests", dependencies: ["PythonTeacherCore"]),
        .testTarget(name: "PythonTeacherAppTests", dependencies: ["PythonTeacherApp", "PythonTeacherCore"])
    ]
)
