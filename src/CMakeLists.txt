cmake_minimum_required(VERSION 3.10)

project(four_fingerprint_library VERSION 2.0.0 LANGUAGES C CXX)

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
  fp_guidance.c
  fp_nbis_wrapper.c
  fp_nfiq2_wrapper.c
  )

add_library(four_fingerprint SHARED ${FP_SOURCES})

set_target_properties(four_fingerprint PROPERTIES
  PUBLIC_HEADER four_fingerprint.h
  OUTPUT_NAME "four_fingerprint"
  C_STANDARD 99
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  )

target_compile_definitions(four_fingerprint PUBLIC DART_SHARED_LIB)
target_include_directories(four_fingerprint PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(four_fingerprint PRIVATE m)

find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  target_compile_definitions(four_fingerprint PRIVATE FP_HAS_ZLIB)
  target_link_libraries(four_fingerprint PRIVATE ZLIB::ZLIB)
endif()

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

option(FP_USE_REAL_NBIS "Link against real NBIS MINDTCT/BOZORTH3" OFF)
option(FP_USE_REAL_NFIQ2 "Link against real NFIQ2 library" OFF)

if(FP_USE_REAL_NBIS)
  set(NBIS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/nbis")
  if(EXISTS "${NBIS_ROOT}/mindtct/src/lib/mindtct/block.c")
    target_compile_definitions(four_fingerprint PRIVATE FP_USE_REAL_NBIS)

    set(NBIS_MINDTCT_SRC
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/block.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/matchpat.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/free.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/imgutil.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/mytime.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/init.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/contour.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/chaincod.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/loop.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/getmin.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/maps.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/shape.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/sort.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/remove.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/results.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/line.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/quality.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/log.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/isempty.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/update.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/binar.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/util.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/to_type9.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/minutia.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/link.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/dft.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/morph.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/detect.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/xytreps.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/globals.c"
      "${NBIS_ROOT}/mindtct/src/lib/mindtct/ridges.c"
      )

    set(NBIS_BOZORTH3_SRC
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bozorth3.c"
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bz_gbls.c"
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bz_sort.c"
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bz_io.c"
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bz_drvrs.c"
      "${NBIS_ROOT}/bozorth3/src/lib/bozorth3/bz_alloc.c"
      )

    set(NBIS_COMMON_SRC
      "${NBIS_ROOT}/commonnbis/src/lib/util/memalloc.c"
      "${NBIS_ROOT}/commonnbis/src/lib/util/fatalerr.c"
      "${NBIS_ROOT}/commonnbis/src/lib/util/syserr.c"
      "${NBIS_ROOT}/commonnbis/src/lib/util/computil.c"
      "${NBIS_ROOT}/commonnbis/src/lib/fft/cfftf.c"
      "${NBIS_ROOT}/commonnbis/src/lib/fft/cfftb.c"
      "${NBIS_ROOT}/commonnbis/src/lib/fft/cffti.c"
      "${NBIS_ROOT}/commonnbis/src/lib/fft/passf.c"
      "${NBIS_ROOT}/commonnbis/src/lib/fft/passb.c"
      )

    set(NBIS_IMGTOOLS_SRC
      "${NBIS_ROOT}/imgtools/src/lib/image/imgutil.c"
      "${NBIS_ROOT}/imgtools/src/lib/image/rgb_ycc.c"
      )

    target_sources(four_fingerprint PRIVATE
      ${NBIS_MINDTCT_SRC}
      ${NBIS_BOZORTH3_SRC}
      ${NBIS_COMMON_SRC}
      ${NBIS_IMGTOOLS_SRC}
      )

    target_include_directories(four_fingerprint PRIVATE
      "${NBIS_ROOT}/mindtct/include"
      "${NBIS_ROOT}/bozorth3/include"
      "${NBIS_ROOT}/commonnbis/include"
      "${NBIS_ROOT}/imgtools/include"
      )
  endif()
endif()

if(FP_USE_REAL_NFIQ2)
  set(NFIQ2_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/nfiq2/NFIQ2/NFIQ2Algorithm/include")
  if(EXISTS "${NFIQ2_INCLUDE_DIR}/nfiq2.hpp")
    target_compile_definitions(four_fingerprint PRIVATE FP_USE_REAL_NFIQ2)
    target_include_directories(four_fingerprint PRIVATE ${NFIQ2_INCLUDE_DIR})

    find_library(NFIQ2_LIBRARY NAMES nfiq2-static-lib nfiq2
      PATHS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/nfiq2/build"
      NO_DEFAULT_PATH
      )
    if(NFIQ2_LIBRARY)
      target_link_libraries(four_fingerprint PRIVATE ${NFIQ2_LIBRARY})
    endif()
  endif()
endif()
