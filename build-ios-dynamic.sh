#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
toolchain_file="${script_dir}/contrib/ios.toolchain.cmake"
ios_output_root="${script_dir}/output-ios-dynamic"
final_output_root="${script_dir}/output"

build_variant() {
  platform="$1"
  build_dir="${script_dir}/build-ios-dynamic-${platform}"
  install_dir="${ios_output_root}/${platform}"

  cmake -S "${script_dir}" -B "${build_dir}" -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}" \
    -DPLATFORM="${platform}" \
    -DENABLE_BITCODE=0 \
    -DDEPLOYMENT_TARGET=12.0 \
    -DBUILD_SQLITE3=OFF \
    -DBUILD_IOS_DYNAMIC_FRAMEWORK=ON \
    -DCMAKE_INSTALL_PREFIX=""

  cmake --build "${build_dir}" --config Release
  cmake --install "${build_dir}" --config Release --prefix "${install_dir}"
}

rm -rf "${ios_output_root}" "${final_output_root}/libsimple-dynamic.xcframework"
mkdir -p "${final_output_root}"

build_variant OS64
build_variant SIMULATOR64
build_variant SIMULATORARM64

sim64_framework="${ios_output_root}/SIMULATOR64/bin/simple.framework"
simarm64_framework="${ios_output_root}/SIMULATORARM64/bin/simple.framework"
sim_universal_dir="${ios_output_root}/SIMULATOR_UNIVERSAL/bin"
sim_universal_framework="${sim_universal_dir}/simple.framework"

mkdir -p "${sim_universal_dir}"
cp -R "${sim64_framework}" "${sim_universal_framework}"
lipo -create \
  "${sim64_framework}/simple" \
  "${simarm64_framework}/simple" \
  -output "${sim_universal_framework}/simple"

xcodebuild -create-xcframework \
  -framework "${ios_output_root}/OS64/bin/simple.framework" \
  -framework "${sim_universal_framework}" \
  -output "${final_output_root}/libsimple-dynamic.xcframework"
