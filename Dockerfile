FROM ruby:2.4
MAINTAINER Kohei Suzuki <eagletmt@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
  apt-get install -y mysql-client nodejs rsync ssh && \
  update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10 && \
  apt-get clean
RUN gem install --no-document foreman

WORKDIR /app

COPY rrrspec-server/rrrspec-server.gemspec /app/rrrspec-server/rrrspec-server.gemspec
COPY rrrspec-server/lib/rrrspec/server/version.rb /app/rrrspec-server/lib/rrrspec/server/version.rb
COPY rrrspec-server/Gemfile /app/rrrspec-server/Gemfile
COPY wait-for-mysql.sh /app

COPY rrrspec-client/rrrspec-client.gemspec /app/rrrspec-client/rrrspec-client.gemspec
COPY rrrspec-client/lib/rrrspec/client/version.rb /app/rrrspec-client/lib/rrrspec/client/version.rb
COPY rrrspec-client/Gemfile /app/rrrspec-client/Gemfile

COPY rrrspec-web/rrrspec-web.gemspec /app/rrrspec-web/rrrspec-web.gemspec
COPY rrrspec-web/lib/rrrspec/web/version.rb /app/rrrspec-web/lib/rrrspec/web/version.rb
COPY rrrspec-web/Gemfile /app/rrrspec-web/Gemfile

RUN cd rrrspec-server && bundle install -j4
RUN cd rrrspec-client && bundle install -j4
RUN cd rrrspec-web && bundle install -j4

COPY . /app
