FROM quay.io/bitriseio/bitrise-base:alpha

ENV ANDROID_SDK_ROOT /opt/android-sdk-linux
# Preserved for backwards compatibility
ENV ANDROID_HOME /opt/android-sdk-linux

# ------------------------------------------------------
# --- Install required tools

RUN add-apt-repository ppa:openjdk-r/ppa
RUN dpkg --add-architecture i386

# Base (non android specific) tools
# -> should be added to bitriseio/docker-bitrise-base

# Dependencies to execute Android builds
RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk openjdk-11-jdk libc6:i386 libstdc++6:i386 libgcc1:i386 libncurses5:i386 libz1:i386 net-tools

# Keystore format has changed since JAVA 8 https://bugs.launchpad.net/ubuntu/+source/openjdk-9/+bug/1743139
RUN mv /etc/ssl/certs/java/cacerts /etc/ssl/certs/java/cacerts.old \
    && keytool -importkeystore -destkeystore /etc/ssl/certs/java/cacerts -deststoretype jks -deststorepass changeit -srckeystore /etc/ssl/certs/java/cacerts.old -srcstoretype pkcs12 -srcstorepass changeit \
    && rm /etc/ssl/certs/java/cacerts.old

# Select JAVA 8  as default
RUN sudo update-java-alternatives --jre-headless --set java-1.8.0-openjdk-amd64
RUN sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac

# ------------------------------------------------------
# --- Download Android Command line Tools into $ANDROID_SDK_ROOT

RUN cd /opt \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip -O android-commandline-tools.zip \
    && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && unzip -q android-commandline-tools.zip -d /tmp/ \
    && mv /tmp/cmdline-tools/ ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm android-commandline-tools.zip && ls -la ${ANDROID_SDK_ROOT}/cmdline-tools/latest/

ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin

# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
#  sdkmanager --list

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

RUN touch /root/.android/repositories.cfg

# Emulator and Platform tools
RUN yes | sdkmanager "emulator" "platform-tools"

# SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.

RUN yes | sdkmanager --update --channel=3
# Please keep all sections in descending order!
RUN yes | sdkmanager \
    "platforms;android-28" \
    "build-tools;28.0.3" \
    "system-images;android-28;google_apis;x86_64" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.2" \
    "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.1"

# ------------------------------------------------------
# --- Install Gradle from PPA

# Gradle PPA
ENV GRADLE_VERSION=5.6.4
ENV PATH=$PATH:"/opt/gradle/gradle-5.6.4/bin/"
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp \
    && unzip -d /opt/gradle /tmp/gradle-*.zip \
    && chmod +775 /opt/gradle \
    && gradle --version \
    && rm -rf /tmp/gradle*

# ------------------------------------------------------
# --- Install Maven 3 from PPA

RUN apt-get purge maven maven2 \
 && apt-get update \
 && apt-get -y install maven \
 && mvn --version

# Reselect JAVA 8  as default
RUN sudo update-java-alternatives --jre-headless --set java-1.8.0-openjdk-amd64
RUN sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# ------------------------------------------------------
# --- Install additional packages

# Required for Android ARM Emulator
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libqt5widgets5
ENV QT_QPA_PLATFORM offscreen
ENV LD_LIBRARY_PATH ${ANDROID_SDK_ROOT}/emulator/lib64:${ANDROID_SDK_ROOT}/emulator/lib64/qt/lib

# -------------------------------------------------------
# Tools to parse apk/aab info in deploy-to-bitrise-io step
ENV APKINFO_TOOLS /opt/apktools
RUN mkdir ${APKINFO_TOOLS}
RUN wget -q https://github.com/google/bundletool/releases/download/1.4.0/bundletool-all-1.4.0.jar -O ${APKINFO_TOOLS}/bundletool.jar
RUN cd /opt \
    && wget -q https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/4.1.1-6503028/aapt2-4.1.1-6503028-linux.jar -O aapt2.jar \
    && unzip -q aapt2.jar aapt2 -d ${APKINFO_TOOLS} \
    && rm aapt2.jar

# ------------------------------------------------------
# --- Cleanup and rev num

# Cleaning
RUN apt-get clean

