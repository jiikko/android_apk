FROM ruby:2.5.1

WORKDIR /android_apk

ENV RUBYOPT -EUTF-8

RUN apt-get update && \
    apt-get install -y unzip \
                       openjdk-8-jdk \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Setup aapt

RUN mkdir -p /android
ENV ANDROID_HOME /android
ADD ./docker/licenses /android/licenses
RUN wget -q -O sdk-tools.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
        unzip -qq sdk-tools.zip -d /android && \
        rm sdk-tools.zip && \
        yes | /android/tools/bin/sdkmanager "build-tools;28.0.3" && \
        ln -s /android/build-tools/28.0.3/aapt /usr/bin/aapt && \
        type aapt

RUN gem update bundler
