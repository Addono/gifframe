# syntax=docker/dockerfile:1
FROM alpine:3.21

LABEL org.opencontainers.image.title="gifframe" \
      org.opencontainers.image.description="Convert terminal screen recordings into polished animated GIFs with macOS-style window chrome" \
      org.opencontainers.image.url="https://github.com/Addono/gifframe" \
      org.opencontainers.image.source="https://github.com/Addono/gifframe" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
        bash \
        ffmpeg \
        imagemagick \
        python3 \
        py3-numpy

COPY bin/gifframe /usr/local/bin/gifframe
RUN chmod +x /usr/local/bin/gifframe

WORKDIR /work

ENTRYPOINT ["gifframe"]
CMD ["--help"]
