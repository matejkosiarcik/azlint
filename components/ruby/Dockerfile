FROM ruby:2.7.1-alpine
WORKDIR /src
COPY Gemfile Gemfile.lock main.sh ./
RUN bundle install
CMD [ "sh", "main.sh" ]
