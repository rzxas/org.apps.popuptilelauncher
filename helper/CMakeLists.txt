cmake_minimum_required(VERSION 3.16)
project(plasma_helper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)

add_executable(plasma_helper
    main.cpp
    PlasmaHelper.cpp
    PlasmaHelper.h
)

target_include_directories(plasma_helper PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(plasma_helper PRIVATE Qt6::Core Qt6::DBus Qt6::Gui)

install(TARGETS plasma_helper RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
