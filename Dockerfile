FROM node:20.12.1-bullseye-slim

RUN apt-get -y update && \
    apt-get -y --no-install-recommends install \
        bash \
        git \
        wget \
        ca-certificates && \
    apt-get -y clean && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN node /usr/local/lib/node_modules/excalidraw-brute-export-cli/node_modules/.bin/playwright \
      install-deps firefox

RUN node /usr/local/lib/node_modules/excalidraw-brute-export-cli/node_modules/.bin/playwright \
      install firefox

COPY render.sh /render.sh
RUN sed -i 's/\r$//' /render.sh && chmod +x /render.sh

WORKDIR /workspace

ENTRYPOINT ["/render.sh"]
