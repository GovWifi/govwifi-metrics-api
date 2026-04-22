FROM ruby:4.0.1-alpine

WORKDIR /usr/src/app

RUN apk add --no-cache build-base postgresql-dev tzdata nodejs bash

RUN addgroup -g 1009 docker && \
    adduser -u 1009 -G docker -h /usr/src/app -s /bin/sh -D docker && \
    chown -R docker:docker /usr/src/app


COPY --chown=docker:docker .ruby-version Gemfile Gemfile.lock* ./
RUN bundle install

COPY --chown=docker:docker . .

COPY --chown=docker:docker entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 4567

USER docker

CMD ["bundle", "exec", "puma", "-p", "8080", "--quiet", "--threads", "8:32"]
