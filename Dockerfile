# STEP 1 - build ruby gems
FROM public.ecr.aws/docker/library/ruby:3.4.9-alpine3.23 AS build
ARG BUNDLE_GITHUB__COM
ENV BUNDLE_GITHUB__COM=$BUNDLE_GITHUB__COM
WORKDIR /
RUN apk add --no-cache --update \
        git \
        postgresql-dev \
        postgresql-client \
        make \
        gcc \
        libev-dev \
        gmp-dev \
        libc-dev \
        tzdata \
    && gem update --system --no-document \
    && gem install bundler
# Create appuser
ENV USER=appuser
ENV UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

COPY --chown=appuser Gemfile* /
RUN bundle config set --local deployment true \
    && bundle config set --local frozen true \
    && bundle config set --local without test:assets:development \
    && bundle config set --local path vendor/bundle \
    && bundle install --jobs 3 --retry 3 \
    && rm -r vendor/bundle/ruby/*/cache/* \
    && find vendor/bundle/ruby/*/gems/*/ext -name "*.c" -or -name "*.o" -delete

# STEP 2 - working image with injected gems
FROM public.ecr.aws/docker/library/ruby:3.2.2-alpine3.17
RUN apk upgrade pkgconfig
RUN apk add --no-cache --update \
        postgresql-client \
        tzdata \
    && gem update --system --no-document \
    && gem install bundler \
    && mkdir /app
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

RUN rm -rf /usr/local/bundle/gems/*/test/rubygems/*.pem
RUN rm -rf /usr/local/bundle/gems/*/test/rubygems/data/*.pem
RUN chown appuser /app
USER appuser:appuser

WORKDIR /app
ADD --chown=appuser . /app
COPY --chown=appuser --from=build /vendor/bundle /app/vendor/bundle
COPY --chown=appuser --from=build /usr/local/bundle/config /usr/local/bundle/config
ENV BUNDLE_PATH=vendor/bundle
ARG RAILS_ENV=production
ENV RAILS_ENV=$RAILS_ENV
ARG APP_BUILD
ENV APP_BUILD=$APP_BUILD
ARG APP_DEPLOYED_AT
ENV APP_DEPLOYED_AT=$APP_DEPLOYED_AT
EXPOSE 3020
ENV PATH="/app/bin:${PATH}"
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3020"]
