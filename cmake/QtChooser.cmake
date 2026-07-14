find_package(Qt6 COMPONENTS Core Widgets LinguistTools Xml Network PrintSupport Svg WebEngineCore WebEngineWidgets WebChannel WebSockets Core5Compat StateMachine QUIET)

if(Qt6_FOUND)
    set(QT_VERSION_MAJOR 6)
    set(QT_VERSION ${Qt6_VERSION})
    set(QT_VERSION_PREFIX "Qt6")
    set(QT_WEBENGINE_LIB Qt6::WebEngineCore)
    set(QT_COMPAT_LIB Qt6::Core5Compat)
    get_filename_component(qt_binary_dir ${Qt6_DIR}/../../../bin/ ABSOLUTE)
    get_filename_component(qt_translations_dir ${Qt6_DIR}/../../../translations/ ABSOLUTE)
else()
    find_package(Qt5 REQUIRED Core Widgets LinguistTools Xml Network PrintSupport Svg)
    set(QT_VERSION_MAJOR 5)
    set(QT_VERSION ${Qt5_VERSION})
    set(QT_VERSION_PREFIX "Qt5")
    set(QT_WEBENGINE_LIB Qt5::WebEngine)
    set(QT_COMPAT_LIB "")
    get_filename_component(qt_binary_dir ${Qt5_DIR}/../../../bin/ ABSOLUTE)
    get_filename_component(qt_translations_dir ${Qt5_DIR}/../../../translations/ ABSOLUTE)
endif()

set(CMAKE_AUTOMOC ON)

macro(qt_add_translation)
    set(_files)
    foreach(_file ${ARGV})
        if(NOT ${_file} STREQUAL ${ARGV0})
            list(APPEND _files ${_file})
        endif()
    endforeach()

    if(QT_VERSION_MAJOR EQUAL 6)
        qt6_add_translation(${ARGV0} ${_files})
    else()
        qt5_add_translation(${ARGV0} ${_files})
    endif()
endmacro()

macro(qt_add_ui)
    set(_files)
    foreach(_file ${ARGV})
        if(NOT ${_file} STREQUAL ${ARGV0})
            list(APPEND _files ${_file})
        endif()
    endforeach()

    if(QT_VERSION_MAJOR EQUAL 6)
        qt6_wrap_ui(${ARGV0} ${_files})
    else()
        qt5_wrap_ui(${ARGV0} ${_files})
    endif()
endmacro()

macro(qt_add_resources)
    set(_files)
    foreach(_file ${ARGV})
        if(NOT ${_file} STREQUAL ${ARGV0})
            list(APPEND _files ${_file})
        endif()
    endforeach()
    message(STATUS ${_files})

    if(QT_VERSION_MAJOR EQUAL 6)
        qt6_add_resources(${ARGV0} ${_files})
    else()
        qt5_add_resources(${ARGV0} ${_files})
    endif()
endmacro()

macro(qt_use_modules)
    if(QT_VERSION_MAJOR EQUAL 6)
        target_link_libraries(${ARGV0}
            Qt6::Core
            Qt6::Gui
            Qt6::Widgets
            Qt6::Xml
            Qt6::Network
            Qt6::PrintSupport
            Qt6::WebEngineCore
            Qt6::WebEngineWidgets
            Qt6::WebSockets
            Qt6::WebChannel
            Qt6::Core5Compat
            Qt6::Svg
            Qt6::StateMachine
        )
    else()
        find_package(Qt5 REQUIRED WebEngine WebEngineWidgets WebSockets WebChannel)
        if(APPLE)
            find_package(Qt5 REQUIRED MacExtras)
            target_link_libraries(${ARGV0} Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Xml Qt5::Network Qt5::PrintSupport Qt5::WebEngine Qt5::WebEngineWidgets Qt5::WebSockets Qt5::WebChannel Qt5::MacExtras)
        else(APPLE)
            target_link_libraries(${ARGV0} Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Xml Qt5::Network Qt5::PrintSupport Qt5::WebEngine Qt5::WebEngineWidgets Qt5::WebSockets Qt5::WebChannel)
        endif(APPLE)
    endif()
endmacro()

macro(qt_suppress_warnings)
    if(APPLE)
        set_target_properties(${ARGV0} PROPERTIES
            COMPILE_FLAGS "-Wno-#warnings")
    endif(APPLE)
endmacro()
