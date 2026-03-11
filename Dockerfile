# syntax=docker/dockerfile:1
FROM alpine:3.21

LABEL org.opencontainers.image.title="mov2gif" \
      org.opencontainers.image.description="Convert terminal screen recordings (.mov) to optimised animated GIFs" \
      org.opencontainers.image.url="https://github.com/Addono/mov2gif" \
      org.opencontainers.image.source="https://github.com/Addono/mov2gif" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
        bash \
        ffmpeg \
        imagemagick \
        python3 \
        py3-numpy

COPY bin/mov2gif /usr/local/bin/mov2gif
RUN chmod +x /usr/local/bin/mov2gif

WORKDIR /work

ENTRYPOINT ["mov2gif"]
CMD ["--help"]
