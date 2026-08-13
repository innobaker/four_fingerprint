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

# Android OpenCV — download full SDK from official OpenCV releases if not present
if(ANDROID)
  set(OPENCV_ANDROID_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/opencv/android")
  set(OPENCV_ANDROID_ZIP "${OPENCV_ANDROID_DIR}/opencv-android-4.10.0.zip")
  set(OPENCV_ANDROID_SDK "${OPENCV_ANDROID_DIR}/sdk/native/jni")

  if(NOT EXISTS "${OPENCV_ANDROID_SDK}/OpenCVConfig.cmake")
    message(STATUS "Downloading OpenCV Android SDK...")
    file(DOWNLOAD
      "https://github.com/opencv/opencv/releases/download/4.10.0/opencv-android-4.10.0.zip"
      "${OPENCV_ANDROID_ZIP}"
      SHOW_PROGRESS
      )
    file(MAKE_DIRECTORY "${OPENCV_ANDROID_DIR}")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf "${OPENCV_ANDROID_ZIP}"
      WORKING_DIRECTORY "${OPENCV_ANDROID_DIR}"
      )
    file(RENAME "${OPENCV_ANDROID_DIR}/OpenCV-android-sdk" "${OPENCV_ANDROID_DIR}/sdk")
  endif()

  set(OpenCV_DIR "${OPENCV_ANDROID_SDK}")
  find_package(OpenCV QUIET)
  if(OpenCV_FOUND)
    target_compile_definitions(four_fingerprint PRIVATE FP_HAS_OPENCV)
    target_include_directories(four_fingerprint PRIVATE ${OpenCV_INCLUDE_DIRS})
    target_link_libraries(four_fingerprint PRIVATE ${OpenCV_LIBS})
  endif()
  target_link_options(four_fingerprint PRIVATE "-Wl,-z,max-page-size=16384")
endif()

# iOS OpenCV framework — download full framework from official OpenCV releases if not present
if(IOS)
  set(OPENCV_IOS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/opencv/ios")
  set(OPENCV_IOS_FRAMEWORK "${OPENCV_IOS_DIR}/opencv2.framework")
  set(OPENCV_IOS_ZIP "${OPENCV_IOS_DIR}/opencv2.framework.zip")

  if(NOT EXISTS "${OPENCV_IOS_FRAMEWORK}")
    message(STATUS "Downloading OpenCV iOS framework...")
    file(DOWNLOAD
      "https://github.com/opencv/opencv/releases/download/4.10.0/opencv2.framework.zip"
      "${OPENCV_IOS_ZIP}"
      SHOW_PROGRESS
      )
    file(MAKE_DIRECTORY "${OPENCV_IOS_DIR}")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf "${OPENCV_IOS_ZIP}"
      WORKING_DIRECTORY "${OPENCV_IOS_DIR}"
      )
  endif()

  target_compile_definitions(four_fingerprint PRIVATE FP_HAS_OPENCV)
  target_include_directories(four_fingerprint PRIVATE
    "${OPENCV_IOS_FRAMEWORK}/Versions/A/Headers")
  target_link_libraries(four_fingerprint PRIVATE
    "-framework opencv2")
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
