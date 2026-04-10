FROM ruby:4.0.1-alpine

RUN apk add --no-cache build-base postgresql-dev tzdata nodejs bash

WORKDIR /usr/src/app

COPY .ruby-version Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-p", "8080", "--quiet", "--threads", "8:32"]
