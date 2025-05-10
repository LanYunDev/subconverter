#!/bin/bash
set -xe

# 安装基本构建工具和依赖
apk add --no-cache git gcc g++ musl-dev build-base linux-headers cmake make autoconf automake pkgconfig libtool python3 python3-dev py3-pip
apk add --no-cache zlib-dev zlib-static libidn2-dev rapidjson-dev zlib-static libpsl-static libidn2-static libunistring-static cargo rust
apk add --no-cache openssl-dev openssl-libs-static nghttp2-static nghttp2-dev brotli-static brotli-dev zstd-static zstd-dev libffi-dev \
    libpsl-dev libpsl-static mbedtls-static

python3 -m venv /tmp/venv
. /tmp/venv/bin/activate
pip3 install --no-cache-dir \
    gitpython \
    jsonschema \
    jinja2 \
    GitPython \
    cryptography \
    PyYAML \
    mypy \
    pylint
git clone --depth=1 --recursive --shallow-submodules https://github.com/Mbed-TLS/mbedtls.git
cd mbedtls
cmake -B build -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON -DUSE_SHARED_MBEDTLS_LIBRARY=OFF .
make install -j$(nproc)
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/c-ares/c-ares.git
cd c-ares
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCARES_STATIC=ON -DCARES_SHARED=OFF .
cmake --build build -- -j${THREADS}
cmake --install build
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/curl/curl
cd curl
# cmake -DCURL_USE_MBEDTLS=ON -DHTTP_ONLY=ON -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_USE_LIBSSH2=OFF -DBUILD_CURL_EXE=OFF . > /dev/null
cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_CURL_EXE=OFF \
    -DUSE_LIBIDN2=ON \
    -DENABLE_ARES=ON \
    -DCURL_USE_OPENSSL=ON \
    -DCMAKE_USE_LIBSSH2=OFF \
    -DCURL_ZLIB=ON . > /dev/null
cmake --build build -- -j${THREADS}
cmake --install build
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/PCRE2Project/pcre2.git
cd pcre2
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF . > /dev/null
cmake --build build -- -j$(nproc) > /dev/null
cmake --install build
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/jbeder/yaml-cpp
cd yaml-cpp
cmake -DCMAKE_BUILD_TYPE=Release -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF . > /dev/null
make install -j$(nproc) > /dev/null
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/ftk/quickjspp
cd quickjspp
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make quickjs -j$(nproc) > /dev/null
install -d /usr/lib/quickjs/
install -m644 quickjs/libquickjs.a /usr/lib/quickjs/
install -d /usr/include/quickjs/
install -m644 ../quickjs/quickjs.h ../quickjs/quickjs-libc.h /usr/include/quickjs/
install -m644 ../quickjspp.hpp /usr/include/
cd ../..

git clone --depth=1 --recursive --shallow-submodules https://github.com/PerMalmberg/libcron
cd libcron
git submodule update --init
cmake -DCMAKE_BUILD_TYPE=Release .
make libcron install -j$(nproc) > /dev/null
cd ..

git clone --depth=1 --recursive --shallow-submodules https://github.com/ToruNiina/toml11
cd toml11
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=11 -DCMAKE_INSTALL_PREFIX=/usr/local .
make install -j$(nproc) > /dev/null
cd ..

export PKG_CONFIG_PATH=/usr/lib64/pkgconfig
cmake -DCMAKE_BUILD_TYPE=Release .
make -j$(nproc) > /dev/null
rm subconverter
# shellcheck disable=SC2046
# 使用静态库路径，添加libunistring链接
g++ -o base/subconverter $(find CMakeFiles/subconverter.dir/src/ -name "*.o") -static -lpcre2-8 -lyaml-cpp -L/usr/lib64 -lcurl \
    -lmbedtls -lmbedcrypto -lmbedx509 -lz -l:quickjs/libquickjs.a -llibcron -L/usr/lib -lpsl -lidn2 -lunistring \
    -lssl -lcrypto -lnghttp2 -lbrotlidec -lbrotlienc -lbrotlicommon -lzstd -lcares -O3 -s

# 更新规则
python3 scripts/update_rules.py -c scripts/rules_config.conf
deactivate

cd base
chmod +rx subconverter
chmod +r ./*
cd ..
mv base subconverter
