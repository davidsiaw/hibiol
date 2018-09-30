FROM ruby:2.4.4-alpine3.6

RUN mkdir /app

ADD css /app/css
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
ADD source /app/source
ADD js /app/js
ADD Sumomofile /app/Sumomofile
ADD Procfile /app/Procfile

WORKDIR app

RUN apk update && apk add nodejs make gcc build-base graphviz && bundle install

ADD start.sh /app/start.sh

ENTRYPOINT ["sh", "start.sh"]
