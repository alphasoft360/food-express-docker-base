# Headless Android toolchain (no Android Studio) for building Expo dev-client APKs.
FROM node:20.19.5-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends openjdk-17-jdk-headless unzip rsync \
 && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    NPM_CONFIG_CACHE=/npm-cache \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    HUSKY=0 \
    EXPO_NO_TELEMETRY=1
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

ARG CMDLINE_TOOLS=commandlinetools-linux-13114758_latest.zip
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
 && curl -fsSL https://dl.google.com/android/repository/$CMDLINE_TOOLS -o /tmp/t.zip \
 && unzip -q /tmp/t.zip -d $ANDROID_HOME/cmdline-tools \
 && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
 && rm /tmp/t.zip \
 && yes | sdkmanager --licenses > /dev/null \
 && sdkmanager --install "platform-tools" "platforms;android-35" "platforms;android-36" \
      "build-tools;35.0.0" "build-tools;36.0.0" "ndk;27.1.12297006" "cmake;3.22.1" > /dev/null
# Anything else a given RN/Expo version wants, Gradle downloads itself (licenses accepted above).

RUN git config --system url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --system --add url."https://github.com/".insteadOf "git@github.com:"

COPY build.sh /usr/local/bin/build-apk
RUN sed -i 's/\r$//' /usr/local/bin/build-apk && chmod +x /usr/local/bin/build-apk
ENTRYPOINT ["build-apk"]
