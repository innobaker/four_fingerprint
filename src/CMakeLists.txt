# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(four_fingerprint_library VERSION 1.0.0 LANGUAGES C)

set(FP_SOURCES
  four_fingerprint.c
  fp_utils.c
  fp_calibration.c
  fp_segmentation.c
  fp_illumination.c
  fp_unwarp.c
  fp_liveness.c
  fp_quality.c
  fp_minutiae.c
  fp_matching.c
  fp_iso19794.c
  fp_wsq.c
  fp_crypto.c
  fp_state_machine.c
  fp_pipeline.c
)

add_library(four_fingerprint SHARED ${FP_SOURCES})

set_target_properties(four_fingerprint PROPERTIES
  PUBLIC_HEADER four_fingerprint.h
  OUTPUT_NAME "four_fingerprint"
  C_STANDARD 99
)

target_compile_definitions(four_fingerprint PUBLIC DART_SHARED_LIB)
target_include_directories(four_fingerprint PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(four_fingerprint PRIVATE m)

# Optional zlib for WSQ compression
find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  target_compile_definitions(four_fingerprint PRIVATE FP_HAS_ZLIB)
  target_link_libraries(four_fingerprint PRIVATE ZLIB::ZLIB)
endif()

# Android OpenCV from bundled third_party
if(ANDROID)
  set(OPENCV_ANDROID_SDK "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/opencv/android/sdk/native/jni")
  if(EXISTS "${OPENCV_ANDROID_SDK}/OpenCVConfig.cmake")
    set(OpenCV_DIR "${OPENCV_ANDROID_SDK}")
    find_package(OpenCV QUIET)
    if(OpenCV_FOUND)
      target_compile_definitions(four_fingerprint PRIVATE FP_HAS_OPENCV)
      target_include_directories(four_fingerprint PRIVATE ${OpenCV_INCLUDE_DIRS})
      target_link_libraries(four_fingerprint PRIVATE ${OpenCV_LIBS})
    endif()
  endif()
  target_link_options(four_fingerprint PRIVATE "-Wl,-z,max-page-size=16384")
endif()

# iOS OpenCV framework
if(IOS)
  set(OPENCV_IOS_FRAMEWORK "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/opencv/ios/opencv2.framework")
  if(EXISTS "${OPENCV_IOS_FRAMEWORK}")
    target_compile_definitions(four_fingerprint PRIVATE FP_HAS_OPENCV)
    target_include_directories(four_fingerprint PRIVATE
      "${OPENCV_IOS_FRAMEWORK}/Versions/A/Headers")
    target_link_libraries(four_fingerprint PRIVATE
      "-framework opencv2")
  endif()
endif()

# Desktop Linux/macOS: system OpenCV optional
if(NOT ANDROID AND NOT IOS)
  find_package(OpenCV QUIET)
  if(OpenCV_FOUND)
    target_compile_definitions(four_fingerprint PRIVATE FP_HAS_OPENCV)
    target_include_directories(four_fingerprint PRIVATE ${OpenCV_INCLUDE_DIRS})
    target_link_libraries(four_fingerprint PRIVATE ${OpenCV_LIBS})
  endif()
endif()

if(UNIX AND NOT APPLE AND NOT ANDROID)
  target_link_libraries(four_fingerprint PRIVATE dl)
endif()
