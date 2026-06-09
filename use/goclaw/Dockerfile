# Minimal goclaw runtime - binary mounted from RELEASES
FROM alpine:3.23

RUN apk add --no-cache ca-certificates sudo

COPY ./ROOT /

# Uncomment to wrap the command (e.g. set umask 0002)
ENTRYPOINT [ "/entrypoint.sh" ]

