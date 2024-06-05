##########################################################################
## Dockerfile for SA@OSU
##########################################################################
FROM ruby:3.3-slim-bullseye as bundler

# Necessary for bundler to properly install some gems
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

##########################################################################
## Install dependencies
##########################################################################
FROM bundler as dependencies

RUN apt update && apt -y upgrade && \
  apt -y install \
  nodejs \
  ghostscript \
  vim \
  yarn \
  git \
  mariadb-client libmariadb-dev \
  curl wget \
  less \
  build-essential \
  tzdata \
  zip \
  libtool \
  bash bash-completion \
  java-common openjdk-17-jre-headless \
  python-is-python3 \
  libpq-dev \
  postgresql \
  ffmpeg mediainfo exiftool

# Set up to install newest version of Yarn instead of .32
RUN apt remove cmdtest -y && \
  apt remove yarn -y && \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install yarn -y

RUN yarn install

# RUN /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"

  # Install ImageMagick with full support
RUN t=$(mktemp) && \
wget 'https://raw.githubusercontent.com/SoftCreatR/imei/main/imei.sh' -qO "$t" && \
bash "$t" --imagemagick-version=7.0.11-14 --skip-jxl && \
rm "$t"

# Set the timezone to America/Los_Angeles (Pacific) then get rid of tzdata
RUN cp -f /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
echo 'America/Los_Angeles' > /etc/timezone

# download and install FITS from Github
RUN mkdir -p /opt/fits && \
curl -fSL -o /opt/fits-1.6.0.zip https://github.com/harvard-lts/fits/releases/download/1.6.0/fits-1.6.0.zip && \
cd /opt/fits && unzip /opt/fits-1.6.0.zip  && chmod +X fits.sh && \
rm -f /opt/fits-1.6.0.zip && \
rm /opt/fits/tools/mediainfo/linux/libmediainfo.so.0

FROM dependencies as gems

RUN mkdir /data
WORKDIR /data

ADD Gemfile /data/Gemfile
ADD Gemfile.lock /data/Gemfile.lock
RUN mkdir /data/build

ARG RAILS_ENV=${RAILS_ENV}
ENV RAILS_ENV=${RAILS_ENV}

ADD ./build/install_gems.sh /data/build
RUN ./build/install_gems.sh && bundle clean --force