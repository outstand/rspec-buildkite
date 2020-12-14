FROM ruby:2.7.2-alpine3.12
LABEL maintainer="Ryan Schlesinger <ryan@outstand.com>"

RUN apk add --no-cache ca-certificates wget openssl jq git bash tini su-exec build-base

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV BUNDLER_VERSION 2.1.4
RUN gem install bundler -v ${BUNDLER_VERSION} -i /usr/local/lib/ruby/gems/$(ls /usr/local/lib/ruby/gems) --force

RUN addgroup -g 1000 -S srv && \
    adduser -u 1000 -S -G srv srv

WORKDIR /srv
RUN chown -R srv:srv /srv
COPY --chown=srv:srv Gemfile Gemfile.lock rspec-buildkite.gemspec /srv/
COPY --chown=srv:srv lib/rspec/buildkite/version.rb /srv/lib/rspec/buildkite/version.rb

USER srv
RUN bundle install

COPY --chown=srv:srv . /srv/
CMD ["rake"]
