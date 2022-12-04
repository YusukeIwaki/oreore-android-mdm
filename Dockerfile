FROM ruby:3.1-alpine

RUN apk add --no-cache \
    bash \
    build-base \
    git \
    less \
    libxml2-dev \
    libxslt-dev \
    postgresql-dev \
    shared-mime-info \
    tzdata

COPY --chmod=0755 docker_entrypoint.sh /
ENTRYPOINT [ "/docker_entrypoint.sh" ]
