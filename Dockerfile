# syntax=docker/dockerfile:1
FROM ubuntu:22.04

LABEL org.opencontainers.image.title="mov2gif" \
      org.opencontainers.image.description="Convert terminal screen recordings (.mov) to optimised animated GIFs" \
      org.opencontainers.image.url="https://github.com/Addono/mov2gif" \
      org.opencontainers.image.source="https://github.com/Addono/mov2gif" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        imagemagick \
        python3 \
        python3-numpy \
    && rm -rf /var/lib/apt/lists/*

# ImageMagick ships with a restrictive security policy on Ubuntu.
# Relax the policy for the formats this tool needs.
RUN sed -i \
        -e 's|rights="none" pattern="PS"|rights="read|write" pattern="PS"|g' \
        -e 's|rights="none" pattern="EPS"|rights="read|write" pattern="EPS"|g' \
        -e 's|rights="none" pattern="PDF"|rights="read|write" pattern="PDF"|g' \
    /etc/ImageMagick-6/policy.xml 2>/dev/null || true

COPY bin/mov2gif /usr/local/bin/mov2gif
RUN chmod +x /usr/local/bin/mov2gif

WORKDIR /work

ENTRYPOINT ["mov2gif"]
CMD ["--help"]
