ARG IMG_TAG=latest

# Fetch libwasmvm_muslc (cosmwasmvm)
FROM alpine AS cosmwasm-lib
ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0-beta10/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.x86_64.a
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 2f44efa9c6c1cda138bd1f46d8d53c5ebfe1f4a53cf3457b01db86472c4917ac
# Copy the library you want to the final location that will be found by the linker flag `-lwasmvm_muslc`
RUN cp /lib/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.a

# Fetch base packages
FROM golang:1.18-alpine AS base-builder
ENV PACKAGES make git libc-dev gcc linux-headers
RUN apk add --no-cache $PACKAGES

# Compile the umeed binary
FROM base-builder AS umeed-builder
ARG UMEE_VERSION="main"
RUN git clone --branch="${UMEE_VERSION}" https://github.com/umee-network/umee.git /src/app/umee
WORKDIR /src/app/umee

RUN go mod download
COPY --from=cosmwasm-lib /lib/libwasmvm_muslc.a /lib/libwasmvm_muslc.a
RUN apk add --no-cache curl bash eudev-dev python3
# RUN BUILD_TAGS=muslc LINK_STATICALLY=true make install
RUN BUILD_TAGS=muslc LINK_STATICALLY=true make build
# RUN ls /src/app/umee
# RUN ls /src/app/umee/build
# RUN /src/app/umee/build/umeed --help
RUN cd price-feeder && BUILD_TAGS=muslc LINK_STATICALLY=true make install
# RUN ls /go/bin

# Fetch peggo (gravity bridge) binary
FROM base-builder AS peggo-builder
ARG PEGGO_VERSION=v0.3.0
WORKDIR /downloads/
RUN git clone --branch="${PEGGO_VERSION}" https://github.com/umee-network/peggo.git
RUN cd peggo && make build && cp ./build/peggo /usr/local/bin/

# Add to a distroless container
# FROM gcr.io/distroless/cc:IMG_TAG
FROM gcr.io/distroless/cc:debug
ARG IMG_TAG
COPY --from=cosmwasm-lib /lib/libwasmvm_muslc.a /lib/libwasmvm_muslc.a
COPY --from=umeed-builder /src/app/umee/build/umeed /usr/local/bin/
COPY --from=umeed-builder /go/bin/price-feeder /usr/local/bin/
COPY --from=peggo-builder /usr/local/bin/peggo /usr/local/bin/
EXPOSE 26656 26657 1317 9090 7171

# ENTRYPOINT ["umeed", "start"]