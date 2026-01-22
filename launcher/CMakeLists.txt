cmake_minimum_required(VERSION 3.16)
project(plasma_launcher_example LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QML_IMPORT_DIR ${CMAKE_CURRENT_BINARY_DIR}/imports/org/apps/launcher)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick DBus)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6KIO REQUIRED COMPONENTS KIOCore KIOGui)

add_executable(launcher main.cpp Launcher.cpp Launcher.h)
add_library(helper_plugin SHARED
    HelperPlugin.cpp
    HelperPlugin.h
    HelperBridge.cpp
    HelperBridge.h
)
target_link_libraries(helper_plugin PRIVATE
    Qt6::Core Qt6::Qml Qt6::DBus
)
set_target_properties(helper_plugin PROPERTIES
    OUTPUT_NAME "org.apps.launcher"
)
target_sources(launcher PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/HelperBridge.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/HelperBridge.h
    resources.qrc
)
target_link_libraries(launcher PRIVATE
    Qt6::Core Qt6::DBus Qt6::Qml Qt6::Quick
    KF6::CoreAddons
    KF6::Service
    KF6::KIOCore KF6::KIOGui
)
install(TARGETS launcher RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(TARGETS helper_plugin LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qt6/qml/org/apps/launcher)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/imports/org/apps/launcher/qmldir
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/qt6/qml/org/apps/launcher)
