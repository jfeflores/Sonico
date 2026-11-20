# The C++ libraries remain managed by the parent project. Compile the Swift app
# separately so Unix Makefiles and Command Line Tools work as well as full Xcode.
find_program(XM_SWIFTC swiftc REQUIRED)
find_program(XM_XCRUN xcrun REQUIRED)
execute_process(COMMAND xcrun --sdk macosx --show-sdk-path
    OUTPUT_VARIABLE XM_SDK OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)

set(XM_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
if (CMAKE_OSX_ARCHITECTURES)
    list(LENGTH CMAKE_OSX_ARCHITECTURES XM_ARCH_COUNT)
    if (NOT XM_ARCH_COUNT EQUAL 1)
        message(FATAL_ERROR "Native app currently builds one architecture at a time; use arm64 or x86_64")
    endif ()
    set(XM_ARCH "${CMAKE_OSX_ARCHITECTURES}")
endif ()
set(XM_APP "${CMAKE_CURRENT_BINARY_DIR}/Sonico.app")
set(XM_EXECUTABLE "${XM_APP}/Contents/MacOS/Sonico")
set(XM_ICON "${CMAKE_CURRENT_SOURCE_DIR}/Icon/AppIcon.icon")
file(GLOB_RECURSE XM_ICON_SOURCES CONFIGURE_DEPENDS "${XM_ICON}/*")
set(XM_ICON_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/icon")
option(SONICO_ADAPTIVE_ICON "Compile adaptive icon when Xcode 26+ is available" ON)
execute_process(COMMAND "${XM_XCRUN}" actool --version --output-format human-readable-text
    RESULT_VARIABLE XM_ACTOOL_STATUS OUTPUT_VARIABLE XM_ACTOOL_VERSION ERROR_QUIET)
# Older Xcode and the standalone Command Line Tools can still produce the app.
set(XM_ICON_MODE legacy)
if (SONICO_ADAPTIVE_ICON AND XM_ACTOOL_STATUS EQUAL 0 AND XM_ACTOOL_VERSION MATCHES "short-bundle-version: ([0-9]+)[.]")
    if (CMAKE_MATCH_1 GREATER_EQUAL 26)
        set(XM_ICON_MODE adaptive)
    endif ()
endif ()
set(XM_ICON_FILES "${CMAKE_CURRENT_SOURCE_DIR}/Icon/AppIcon.icns")
if (XM_ICON_MODE STREQUAL "adaptive")
    set(XM_ICON_FILES "${XM_ICON_OUTPUT}/Assets.car" "${XM_ICON_OUTPUT}/AppIcon.icns")
    add_custom_command(OUTPUT ${XM_ICON_FILES}
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${XM_ICON_OUTPUT}"
        COMMAND "${XM_XCRUN}" actool "${XM_ICON}" --compile "${XM_ICON_OUTPUT}" --platform macosx
            --minimum-deployment-target 15.0 --app-icon AppIcon
            --output-partial-info-plist "${XM_ICON_OUTPUT}/Info.plist"
            --output-format human-readable-text --errors --warnings
        DEPENDS ${XM_ICON_SOURCES}
        VERBATIM COMMENT "Compiling Sonico adaptive icon")
else ()
    message(STATUS "Sonico: using static macOS app icon; adaptive looks require Xcode 26+")
endif ()
file(CONFIGURE OUTPUT "${XM_ICON_OUTPUT}/mode.txt" CONTENT "${XM_ICON_MODE}\n")
file(GLOB XM_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Sources/*.swift")
set(XM_SWIFT_FLAGS -swift-version 6 -parse-as-library -target "${XM_ARCH}-apple-macosx15.0"
    -sdk "${XM_SDK}" -I "${CMAKE_CURRENT_SOURCE_DIR}/Bridge"
    -Xcc "-I${PROJECT_SOURCE_DIR}/libmdr/include"
    -Xcc "-I${PROJECT_SOURCE_DIR}/libmdr-bt/include")
set(XM_LINK_FLAGS -lc++ -framework Foundation -framework IOBluetooth)
set(XM_NOTICES
    "${PROJECT_SOURCE_DIR}/LICENSES/NOTICE.txt"
    "${PROJECT_SOURCE_DIR}/LICENSES/MIT-SonyHeadphonesClient.txt"
    "${PROJECT_SOURCE_DIR}/LICENSES/MIT-Plutoberth.txt"
    "${CMAKE_CURRENT_SOURCE_DIR}/Resources/FMT-LICENSE.txt")

add_custom_command(OUTPUT "${XM_EXECUTABLE}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${XM_APP}/Contents/MacOS" "${XM_APP}/Contents/Resources"
    COMMAND "${XM_SWIFTC}" ${XM_SWIFT_FLAGS} -O ${XM_SOURCES}
        $<TARGET_FILE:mdr> $<TARGET_FILE:mdr-bt> ${XM_LINK_FLAGS} -o "${XM_EXECUTABLE}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist" "${XM_APP}/Contents/Info.plist"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${PROJECT_SOURCE_DIR}/LICENSE" "${XM_APP}/Contents/Resources/LICENSE.txt"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${XM_NOTICES} "${XM_APP}/Contents/Resources"
    COMMAND "${CMAKE_COMMAND}" -E rm -f "${XM_APP}/Contents/Resources/Assets.car"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${XM_ICON_FILES} "${XM_APP}/Contents/Resources"
    COMMAND codesign --force --sign - "${XM_APP}"
    DEPENDS ${XM_SOURCES} mdr mdr-bt ${XM_ICON_FILES} "${XM_ICON_OUTPUT}/mode.txt" "${CMAKE_CURRENT_SOURCE_DIR}/Bridge/XMConnectBridge.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/Bridge/module.modulemap" "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist"
        "${PROJECT_SOURCE_DIR}/LICENSE" ${XM_NOTICES}
    VERBATIM COMMENT "Building native Sonico (macOS 15+)" )
add_custom_target(Sonico DEPENDS "${XM_EXECUTABLE}")

if (MDR_BUILD_TESTING)
    enable_testing()
    set(XM_TEST "${CMAKE_CURRENT_BINARY_DIR}/xmconnect-model-tests")
    set(XM_TEST_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/Sources/Domain.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/AdvancedDeviceSettings.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/DeviceSettingService.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/ShortcutLayout.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Tests/AdvancedDeviceSettingsTests.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/FinishPalette.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/HeadphoneModel.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/HeadphoneService.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Sources/PortraitOrbit.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/Tests/ModelTests.swift")
    add_custom_command(OUTPUT "${XM_TEST}"
        COMMAND "${XM_SWIFTC}" ${XM_SWIFT_FLAGS} ${XM_TEST_SOURCES}
            $<TARGET_FILE:mdr> $<TARGET_FILE:mdr-bt> ${XM_LINK_FLAGS} -o "${XM_TEST}"
        DEPENDS ${XM_TEST_SOURCES} mdr mdr-bt "${CMAKE_CURRENT_SOURCE_DIR}/Bridge/XMConnectBridge.h"
        VERBATIM)
    add_custom_target(xmconnect_tests DEPENDS "${XM_TEST}")
    # enable_testing at the root generates the final test tree.
    add_test(NAME xmconnect-model COMMAND "${XM_TEST}")
endif ()
