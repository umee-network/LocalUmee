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
# UMEE_VERSION needs to be an branch with cosmwasm enabled
# otherwise the dockerfile would be different
ARG UMEE_VERSION="rafilx/umeed-cosmwasmd"
RUN git clone --branch="${UMEE_VERSION}" https://github.com/umee-network/umee.git /src/app/umee
WORKDIR /src/app/umee
RUN go mod download

COPY --from=cosmwasm-lib /lib/libwasmvm_muslc.a /lib/libwasmvm_muslc.a
RUN apk add --no-cache curl bash eudev-dev python3
RUN cd price-feeder && BUILD_TAGS=muslc LINK_STATICALLY=true make install

FROM alpine
COPY --from=umeed-builder /go/bin/price-feeder /usr/local/bin/
COPY price-feeder.config.toml /root/price-feeder.config.toml
CMD price-feeder /root/price-feeder.config.toml --log-level debug

# EXPOSE 26656 26657 1317 9090 7171
EXPOSE 7171
