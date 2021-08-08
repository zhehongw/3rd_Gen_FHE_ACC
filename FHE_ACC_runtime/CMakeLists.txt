cmake_minimum_required(VERSION 3.16.0)
project(FHE_ACC_runtime VERSION 1.0 LANGUAGES CXX)

#set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror -O3 -std=c++14")
set (source_dir "${PROJECT_SOURCE_DIR}/src/")
set (include_dir "${PROJECT_SOURCE_DIR}/include/")
set (app_dir "${PROJECT_SOURCE_DIR}/apps")
set (aws_include_dir "$ENV{SDK_DIR}/userspace/include")

#set preprocessing definitions
add_compile_definitions(NDEBUG)
#add_compile_definitions(DEBUG)

#Can manually add the sources using the set command as follows:
#set(SOURCES src/test.cpp src/main.cpp src/nbt.cpp src/params.cpp)

#However, the file(GLOB...) allows for wildcard additions:
#compile my onw library
file(GLOB SOURCES ${source_dir}/*.cpp ${include_dir}/*.h)

add_library(fhe_acc_lib ${SOURCES})

set_target_properties(fhe_acc_lib PROPERTIES CXX_STANDARD 14)
target_compile_options(fhe_acc_lib PRIVATE -Wall -Werror -O3)

#get_target_property(MAIN_CFLAGS mylib COMPILE_OPTIONS)
# also see: COMPILE_DEFINITIONS INCLUDE_DIRECTORIES
#message("-- Target compiler flags are: ${MAIN_CFLAGS}")
target_include_directories(fhe_acc_lib PRIVATE ${aws_include_dir})
target_include_directories(fhe_acc_lib PRIVATE ${include_dir})
target_link_libraries(fhe_acc_lib PRIVATE m)
target_link_libraries(fhe_acc_lib PRIVATE fpga_mgmt)

#compile each of the application files for executables
file(GLOB APPS RELATIVE ${app_dir} ${app_dir}/*.cpp)
foreach( appfile ${APPS})
	#set the executable target
	string(REPLACE ".cpp" "" exename ${appfile})
	add_executable(${exename} ${app_dir}/${appfile})
	#set the compile options
	set_target_properties(${exename} PROPERTIES CXX_STANDARD 14)
	target_compile_options(${exename} PRIVATE -Wall -Werror -O3)
	#set include directories for the headers
	target_include_directories(${exename} PRIVATE ${aws_include_dir})
	target_include_directories(${exename} PRIVATE ${include_dir})
	#add link libraries
	target_link_libraries(${exename} PRIVATE fhe_acc_lib)
	target_link_libraries(${exename} PRIVATE m)
	target_link_libraries(${exename} PRIVATE fpga_mgmt)
endforeach(appfile ${APPS})


#to build in the build directory, simply "cd build", after "cmake ..", "make" in the build directory
