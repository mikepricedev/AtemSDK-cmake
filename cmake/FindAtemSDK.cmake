set(_findPkgName "${CMAKE_FIND_PACKAGE_NAME}")
set(_findQuiet "${${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY}")
set(_findRequired "${${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED}")
set(_findVersion "${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION}")

set(_versionWarningMsg "Does not support \"VERSION\".  Legacy headers are listed in ${_findPkgName}_LEGACY_H.")

set(_atemSDKNotFoundMSg "${_findPkgName} not found.  ATEM Software Control must be installed on system.")

if(WIN32)
  
  set(_atemSDKSearchExt "idl")
  
elseif(APPLE AND NOT IOS)
  
  set(_atemSDKSearchExt "h")
    
  string(APPEND _versionWarningMsg "  Legacy cpp files are listed in ${_findPkgName}_LEGACY_CPP.")

else()
  message(FATAL_ERROR "BMD Atem SDK is intended for MacOS and Windows only.")
endif()

if(_findVersion AND NOT _findQuiet)
  message(WARNING "${_versionWarningMsg}")
endif()

# Get all blackmagic and atem directories
foreach(_appsDir IN LISTS 
  CMAKE_SYSTEM_APPBUNDLE_PATH
  CMAKE_SYSTEM_PROGRAM_PATH
  CMAKE_SYSTEM_PREFIX_PATH
)

  file(GLOB _foundBMDAtemDirs
    LIST_DIRECTORIES TRUE
    "${_appsDir}/*blackmagic*"
    "${_appsDir}/*Blackmagic*"
    "${_appsDir}/*atem*"
    "${_appsDir}/*Atem*"
  )
  
  if(NOT _foundBMDAtemDirs)
    continue()
  endif()
  
  foreach(_bmdAtemDir IN LISTS _foundBMDAtemDirs)
    if(IS_DIRECTORY "${_bmdAtemDir}")
      list(APPEND _bmdAtemDirs "${_bmdAtemDir}")
    endif()
  endforeach()
  

endforeach()

# Search for atem SDK header or idl in blackmagic and atem directories
foreach(_bmdAtemDir IN LISTS _bmdAtemDirs)
  
  file(GLOB_RECURSE _atemSDKIdlOrH
    LIST_DIRECTORIES FALSE
    "${_bmdAtemDir}/*BMDSwitcherAPI.${_atemSDKSearchExt}"
  )
  
  if(_atemSDKIdlOrH)
    break()
  endif()

endforeach()

# Failed to find atem sdk
if(NOT _atemSDKIdlOrH)

  if(_findRequired)
    message(FATAL_ERROR "${_atemSDKNotFoundMSg}")
  elseif(NOT _findQuiet)
    message(WARNING "${_atemSDKNotFoundMSg}")
  endif()

endif()


# Inlcude dir
get_filename_component(_atemSDKIncludeDir "${_atemSDKIdlOrH}" DIRECTORY)


# Get legacy headers or idls
file(GLOB "${_findPkgName}_LEGACY_H"
  LIST_DIRECTORIES FALSE
  "${_atemSDKIncludeDir}/Legacy/*.${_atemSDKSearchExt}"
)

# Get cpp and legacy cpp files for mac.
if(APPLE)

  # Add target
  add_library("${_findPkgName}" STATIC)

  target_include_directories("${_findPkgName}"
    PUBLIC
      "${_atemSDKIncludeDir}"
  )

  # cpp files
  file(GLOB _atemSDKCpp
    LIST_DIRECTORIES FALSE
    "${_atemSDKIncludeDir}/*.cpp"
  )

  # NOTE: Is _atemSDKIdlOrH always the header file on macOS
  target_sources("${_findPkgName}"
    PUBLIC
      "${_atemSDKIdlOrH}"
    PRIVATE
      ${_atemSDKCpp}
  )
  
  # Load CoreFoundation Framework
  find_library(CF_FRAMEWORK CoreFoundation REQUIRED)
  
  target_link_libraries("${_findPkgName}"
    PUBLIC
      "${CF_FRAMEWORK}"
  )

  set_target_properties("${_findPkgName}" PROPERTIES
    CXX_STANDARD_REQUIRED ON
    CXX_STANDARD 14
    LINKER_LANGUAGE CXX
  )

  # Get legacy cpp 
  file(GLOB "${_findPkgName}_LEGACY_CPP"
    LIST_DIRECTORIES FALSE
    "${_atemSDKIncludeDir}/Legacy/*.cpp"
  )

else()

  # Get headers
  file(GLOB _atemSDKHeader
    LIST_DIRECTORIES FALSE
    "${_atemSDKIncludeDir}/*.h"
  )

  if(_atemSDKHeader)
  
    # C files
    file(GLOB _atemSDKC
      LIST_DIRECTORIES FALSE
      "${_atemSDKIncludeDir}/*.c"
    )
  
  # Attempt to find and call midl on the BMDSwitcherAPI.idl
  else()
    
    get_filename_component(_atemSDKIdl "${_atemSDKIdlOrH}" NAME)
    get_filename_component(_atemSDKNameOnly "${_atemSDKIdlOrH}" NAME_WLE)

    if(NOT _findQuiet)
      message(STATUS "No header files found in \"${_atemSDKIncludeDir}\".  Attempting to generate from ${_atemSDKIdl}.")
    endif()
      
    find_program(_midl "midl")
      
    if(NOT _midl)

      message(FATAL_ERROR "Did not find \"midl.exe\".  Ensure the Windows SDK is installed and cmake is running from the Developer Command Prompt or PowerShell.  Or manually run \"midl\" against the idl file \"${_atemSDKIdlOrH}\" and output in the same directory.  Developer PowerShell as Administrator:\ncd \"${_atemSDKIncludeDir}\"\n midl /h ${_atemSDKNameOnly}_h.h /notlb /out . \"${_atemSDKIdl}\"")
    
    endif()
    
    set(_atemSDKIncludeDir "${CMAKE_CURRENT_BINARY_DIR}/_atemSDKIdlGenInlcudeDir")

    file(MAKE_DIRECTORY "${_atemSDKIncludeDir}")

    if(_findQuiet)
      set(_midlQuietness "OUTPUT_QUIET" "ERROR_QUIET")
    else()
      set(_midlQuietness "ECHO_OUTPUT_VARIABLE")
    endif()
    
    execute_process(
      COMMAND "${_midl}" /h "${_atemSDKNameOnly}_h.h" /notlb /out . "${_atemSDKIdlOrH}"
      WORKING_DIRECTORY "${_atemSDKIncludeDir}"
      OUTPUT_VARIABLE _midlOutput
      ERROR_VARIABLE _midlOutput
      ${_midlQuietness}
    )

    string(REGEX MATCH 
      "(command line error : MIDL[0-9]|error MIDL[0-9]|MIDL error)"
      _midlError
    "${_midlOutput}")

    if(_midlError)
      message(FATAL_ERROR "Failed to generate files from \"${_atemSDKIdl}\".\n${_midlOutput}")
    endif()
    
    # Get headers
    file(GLOB _atemSDKHeader
      LIST_DIRECTORIES FALSE
      "${_atemSDKIncludeDir}/*.h"
    )

    # C files
    file(GLOB _atemSDKC
      LIST_DIRECTORIES FALSE
      "${_atemSDKIncludeDir}/*.c"
    )

  endif()
    
  # Add target
  add_library("${_findPkgName}" STATIC)

  target_include_directories("${_findPkgName}"
    PUBLIC
      "${_atemSDKIncludeDir}"
  )

  target_sources("${_findPkgName}"
    PUBLIC
      ${_atemSDKHeader}
    PRIVATE
      ${_atemSDKC}
  )

  set_target_properties("${_findPkgName}" PROPERTIES
    CXX_STANDARD_REQUIRED ON
    C_STANDARD_REQUIRED ON
    CXX_STANDARD 14
    C_STANDARD 11
    LINKER_LANGUAGE CXX
  )
  
endif()
  


add_library("${_findPkgName}::${_findPkgName}" ALIAS "${_findPkgName}")

set("${_findPkgName}_FOUND" TRUE)

if(NOT _findQuiet)
  message(STATUS "${_findPkgName} Found")
endif()
