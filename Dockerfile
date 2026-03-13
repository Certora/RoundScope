# Stage 1: Build all dependencies and RoundScope
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    g++ \
    cmake \
    make \
    git \
    maven \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME dynamically based on what was installed
RUN ln -s /usr/lib/jvm/java-21-openjdk-* /usr/lib/jvm/java-21-openjdk
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk

# Build Solidity from source
WORKDIR /build
COPY solidity-pragma-bypass.patch /build/
RUN git clone --branch v0.8.34 --depth 1 https://github.com/ethereum/solidity.git \
    && cd solidity \
    && git apply /build/solidity-pragma-bypass.patch \
    && git submodule update --init --recursive \
    && mkdir build && cd build \
    && cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON .. \
    && make -j$(nproc)

# Build WALA fork
# Override toolchain to use installed JDK 21 instead of auto-provisioning JDK 25
RUN git clone https://github.com/julian-certora/WALA.git \
    && cd WALA \
    && git checkout fixesToNativeBridge \
    && find . \( -name "*.gradle.kts" -o -name "*.gradle" \) \
       -exec sed -i 's/JavaLanguageVersion.of(25)/JavaLanguageVersion.of(21)/g' {} + \
    && ./gradlew publishToMavenLocal -xtest \
    && ./gradlew :cast:assemble -xtest

# Copy RoundScope source and build
COPY . /build/RoundScope
WORKDIR /build/RoundScope
RUN mvn install

# Build the WALA cast native library from source
RUN mkdir -p /build/WALA/cast/cast/build/lib/main/debug \
    && cd /build/WALA/cast/cast/src/main/cpp \
    && g++ -std=c++17 -fpic -shared -o /build/WALA/cast/cast/build/lib/main/debug/libcast.so \
       *.cpp \
       -I../public \
       -I$JAVA_HOME/include \
       -I$JAVA_HOME/include/linux

# Build JNI native library
WORKDIR "/build/RoundScope/WALA CAst Solidity JNI Bridge"
RUN make -f Makefile.linux

# Stage 2: Slim runtime image
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=builder /build/RoundScope/target/com.certora.RoundScope-0.0.1-SNAPSHOT.jar roundscope.jar
COPY --from=builder ["/build/RoundScope/WALA CAst Solidity JNI Bridge/libwalacastsolidity.so", "."]
COPY --from=builder /build/WALA/cast/cast/build/lib/main/debug/libcast.so .
COPY --from=builder /usr/lib/*/libboost_filesystem.so* ./

ENV LD_LIBRARY_PATH=/app

ENTRYPOINT ["java", "-Djava.library.path=/app", "-jar", "roundscope.jar"]
