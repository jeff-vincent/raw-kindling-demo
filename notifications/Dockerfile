FROM ruby:3.3-alpine
RUN apk add --no-cache build-base
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle install --without development test
COPY . .
EXPOSE 3005
CMD ["ruby", "app.rb"]
