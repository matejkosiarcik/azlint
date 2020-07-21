FROM ruby:2.7.1-alpine
WORKDIR /src
COPY Gemfile Gemfile.lock main.sh ./
RUN gem install bundler && \
    bundle install && \
    gem uninstall bundler

CMD [ "sh", "main.sh" ]
