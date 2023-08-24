FROM alpine:edge
COPY --from=justincormack/nsenter1 /usr/bin/nsenter1 /nsenter1
COPY --from=docker /usr/local/bin/docker /docker
ARG TARGETARCH
RUN apk add curl jq
COPY entry.sh manager.sh /
ENTRYPOINT [ "/entry.sh" ]