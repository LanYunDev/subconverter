# syntax=docker/dockerfile:1.4

####################################
# Builder Stage
####################################
FROM alpine:latest AS builder
LABEL maintainer="lanyun@lanyundev.com"

ARG THREADS="4"
ARG SHA=""
ARG VERSION=latest
ARG TARGETPLATFORM=""

# 输出构建环境信息
RUN echo "Building for platform: ${TARGETPLATFORM}" && \
    echo "CPU arch: $(uname -m)" && \
    echo "Using ${THREADS} threads for build"

# 安装构建依赖
RUN set -xe \
    && apk add --no-cache \
        git zlib-dev zlib-static rapidjson-dev \
        g++ gcc musl-dev libidn2-dev \
        build-base \
        linux-headers \
        cmake make autoconf automake pkgconfig libtool \
        python3 python3-dev py3-pip \
        rapidjson-dev libpsl-static libidn2-static \
        libunistring-static \
        zlib-static \
        openssl-dev \
        openssl-libs-static \
        nghttp2-static \
        nghttp2-dev \
        brotli-static \
        brotli-dev libpsl-dev libpsl-static \
        zstd-static cargo rust \
        zstd-dev libffi-dev \
        bash

# 克隆依赖库
WORKDIR /tmp

# 复制补丁文件
COPY patches/ /tmp/patches/

# 构建mbedtls静态库
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/Mbed-TLS/mbedtls.git /tmp/mbedtls \
    && python3 -m venv /tmp/.venv \
    && source /tmp/.venv/bin/activate \
    && pip3 install --no-cache-dir \
    jsonschema \
    jinja2 \
    GitPython \
    cryptography \
    PyYAML \
    mypy \
    pylint \
    && cd /tmp/mbedtls \
    && if [ "$(uname -m)" = "armv7l" ] || [ "$(uname -m)" = "aarch64" ] || [ "${TARGETPLATFORM}" = "linux/arm/v7" ] || [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        echo "Detected ARM platform (arm/v7 or arm64), applying bounds-check patch" && \
        export CFLAGS="-Wno-error=array-bounds" && \
        export CXXFLAGS="-Wno-error=array-bounds" && \
        patch -p1 < /tmp/patches/0002-mbedtls-arm-bounds-check.patch || true; \
    fi \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON -DUSE_SHARED_MBEDTLS_LIBRARY=OFF . \
    && cmake --build build -- -j${THREADS} \
    && cmake --install build

# 构建c-ares静态库
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/c-ares/c-ares.git /tmp/c-ares \
    && cd /tmp/c-ares \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCARES_STATIC=ON -DCARES_SHARED=OFF . \
    && cmake --build build -- -j${THREADS} \
    && cmake --install build

# 构建curl静态库，链接我们自己构建的c-ares
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/curl/curl.git /tmp/curl \
    && cd /tmp/curl \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_CURL_EXE=OFF \
    -DUSE_LIBIDN2=ON \
    -DENABLE_ARES=ON \
    -DCURL_USE_OPENSSL=ON \
    -DCMAKE_USE_LIBSSH2=OFF \
    -DCURL_ZLIB=ON \
    . \
    && cmake --build build -- -j${THREADS} \
    && cmake --install build

# 构建pcre2静态库
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/PCRE2Project/pcre2.git /tmp/pcre2 \
    && cd /tmp/pcre2 \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF . \
    && cmake --build build -- -j${THREADS} \
    && cmake --install build

# 构建yaml-cpp静态库
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/jbeder/yaml-cpp.git /tmp/yaml-cpp \
    && cd /tmp/yaml-cpp \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DYAML_BUILD_SHARED_LIBS=OFF . \
    && cmake --build build -- -j${THREADS} \
    && cmake --install build

# 构建quickjspp
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/ftk/quickjspp /tmp/quickjspp \
    && cd /tmp/quickjspp \
    && mkdir -p build \
    && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --target quickjs -- -j${THREADS} \
    && install -d /usr/lib/quickjs /usr/include/quickjs \
    && install -m644 quickjs/libquickjs.a /usr/lib/quickjs/ \
    && install -m644 ../quickjs/quickjs.h ../quickjs/quickjs-libc.h /usr/include/quickjs/ \
    && install -m644 ../quickjspp.hpp /usr/include/

# 构建libcron
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/PerMalmberg/libcron /tmp/libcron \
    && cd /tmp/libcron \
    && git submodule update --init --recursive \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release . \
    && cmake --build build --target libcron -- -j${THREADS} \
    && install -m644 libcron/out/Release/liblibcron.a /usr/lib/ \
    && install -d /usr/include/libcron /usr/include/date \
    && install -m644 libcron/include/libcron/* /usr/include/libcron/ \
    && install -m644 libcron/externals/date/include/date/* /usr/include/date/

# 构建toml11
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/ToruNiina/toml11 /tmp/toml11 \
    && cmake -B /tmp/toml11/build -S /tmp/toml11 -DCMAKE_CXX_STANDARD=11 \
    && cmake --build /tmp/toml11/build --target install -- -j${THREADS}

# 克隆subconverter
WORKDIR /
RUN git clone --depth=1 --recursive --shallow-submodules https://github.com/lanyundev/subconverter \
    && cd subconverter \
    && chmod +x ./scripts/remove_headers.sh \
    && OSTYPE=linux-musl ./scripts/remove_headers.sh \
    && source /tmp/.venv/bin/activate \
    && python3 scripts/update_rules.py -c scripts/rules_config.conf \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release . \
    && cmake --build build -- -j${THREADS} \
    && ls -la build/ \
    && file build/subconverter

####################################
# Final Stage
####################################
FROM alpine:latest
LABEL maintainer="lanyun@lanyundev.com"
LABEL org.opencontainers.image.source="https://github.com/lanyundev/subconverter"
LABEL org.opencontainers.image.description="一个代理订阅转换工具"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# 安装运行时依赖和时区数据
RUN set -xe \
    && apk add --no-cache \
        pcre2 \
        libcurl \
        yaml-cpp \
        tzdata \
        curl \
    # 设置时区为亚洲上海
    && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    # 创建非 root 用户以提高安全性
    && addgroup -S appgroup \
    && adduser -S appuser -G appgroup

# 复制二进制文件和资源
COPY --from=builder --chown=appuser:appgroup /subconverter/build/subconverter /usr/bin/
COPY --from=builder --chown=appuser:appgroup /subconverter/base /base/

# 设置运行时配置
USER appuser
WORKDIR /base

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:25500 || exit 1

# 暴露端口并设置启动命令
EXPOSE 25500/tcp
CMD subconverter
# ENTRYPOINT ["/app/subconverter/subconverter"]
# CMD ["--config", "/app/subconverter/config/config.json"]
