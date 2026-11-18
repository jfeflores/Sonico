# The C++ libraries remain managed by the parent project. Compile the Swift app
# separately so Unix Makefiles and Command Line Tools work as well as full Xcode.
find_program(XM_SWIFTC swiftc REQUIRED)
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
set(XM_APP "${CMAKE_CURRENT_BINARY_DIR}/Project XMConnect.app")
set(XM_EXECUTABLE "${XM_APP}/Contents/MacOS/ProjectXMConnect")
file(GLOB XM_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/Sources/*.swift")
set(XM_SWIFT_FLAGS -swift-version 6 -parse-as-library -target "${XM_ARCH}-apple-macosx15.0"
    -sdk "${XM_SDK}" -I "${CMAKE_CURRENT_SOURCE_DIR}/Bridge"
    -Xcc "-I${PROJECT_SOURCE_DIR}/libmdr/include"
    -Xcc "-I${PROJECT_SOURCE_DIR}/libmdr-bt/include")
set(XM_LINK_FLAGS -lc++ -framework Foundation -framework IOBluetooth)

add_custom_command(OUTPUT "${XM_EXECUTABLE}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${XM_APP}/Contents/MacOS" "${XM_APP}/Contents/Resources"
    COMMAND "${XM_SWIFTC}" ${XM_SWIFT_FLAGS} -O ${XM_SOURCES}
        $<TARGET_FILE:mdr> $<TARGET_FILE:mdr-bt> ${XM_LINK_FLAGS} -o "${XM_EXECUTABLE}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist" "${XM_APP}/Contents/Info.plist"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${PROJECT_SOURCE_DIR}/LICENSE" "${XM_APP}/Contents/Resources/LICENSE.txt"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/Resources/FMT-LICENSE.txt" "${XM_APP}/Contents/Resources/FMT-LICENSE.txt"
    COMMAND codesign --force --sign - "${XM_APP}"
    DEPENDS ${XM_SOURCES} mdr mdr-bt "${CMAKE_CURRENT_SOURCE_DIR}/Bridge/XMConnectBridge.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/Bridge/module.modulemap" "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist"
        "${PROJECT_SOURCE_DIR}/LICENSE" "${CMAKE_CURRENT_SOURCE_DIR}/Resources/FMT-LICENSE.txt"
    VERBATIM COMMENT "Building native Project XMConnect (macOS 15+)" )
add_custom_target(ProjectXMConnect DEPENDS "${XM_EXECUTABLE}")

if (MDR_BUILD_TESTING)
    enable_testing()
    set(XM_TEST "${CMAKE_CURRENT_BINARY_DIR}/xmconnect-model-tests")
    set(XM_TEST_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/Sources/Domain.swift"
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
