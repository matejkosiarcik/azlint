FROM ruby:3.0.0-alpine
WORKDIR /src
COPY Gemfile Gemfile.lock main.sh ./
RUN bundle install
CMD [ "sh", "main.sh" ]
