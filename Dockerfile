FROM ruby:4.0.1-slim-bookworm

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    tzdata \
    nodejs \
    bash \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1009 docker && \
    useradd -u 1009 -g docker -d /usr/src/app -s /bin/sh docker && \
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
