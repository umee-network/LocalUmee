# Fetch base packages
FROM golang:1.18-alpine AS base-builder
ENV PACKAGES make git libc-dev gcc linux-headers
RUN apk add --no-cache $PACKAGES

# Fetch peggo (gravity bridge) binary
FROM base-builder AS peggo-builder
ARG PEGGO_VERSION=v0.4.0
WORKDIR /downloads/
RUN git clone --branch="${PEGGO_VERSION}" https://github.com/umee-network/peggo.git
RUN cd peggo && make build && cp ./build/peggo /usr/local/bin/

FROM alpine
COPY --from=peggo-builder /usr/local/bin/peggo /usr/local/bin/

EXPOSE 26656 26657 1317 9090 7171