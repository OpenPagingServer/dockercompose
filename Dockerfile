FROM python:3.12-slim-bookworm

ARG OPS_REF=main
ARG INSTALLER_ENDPOINT=https://install.openpagingserver.org/

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        fontconfig \
        fonts-dejavu-core \
        festival \
        git \
        curl \
        ca-certificates \
        build-essential \
        pkg-config \
        libmariadb-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/OpenPagingServer \
    && curl -fsSL \
         -H "X-OPS-Command: download" \
         "${INSTALLER_ENDPOINT}?ref=$(python -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "${OPS_REF}")" \
         -o /tmp/ops.tar.gz \
    && tar -xzf /tmp/ops.tar.gz -C /opt/OpenPagingServer --strip-components=1 \
    && rm -f /tmp/ops.tar.gz

WORKDIR /opt/OpenPagingServer

RUN pip install --no-cache-dir \
        -r requirements.txt \
        flask-cors \
        requests \
        pillow \
        numpy \
        lxml \
        aiohttp \
        websockets \
        cryptography \
        passlib

RUN mkdir -p /var/lib/openpagingserver/endpointmodules \
    && for repo in \
         "https://github.com/OpenPagingServer/cisco.git" \
         "https://github.com/OpenPagingServer/polycom.git" \
         "https://github.com/OpenPagingServer/yealink.git" \
         "https://github.com/OpenPagingServer/discordwebhook.git"; do \
       repo_path="${repo#https://github.com/}"; \
       repo_path="${repo_path%.git}"; \
       tag="$(git ls-remote --tags --refs "$repo" 'refs/tags/*' 2>/dev/null \
              | awk '{print $2}' | sed 's#refs/tags/##' | sort -V | tail -n 1)"; \
       if [ -n "$tag" ]; then \
         asset_info="$(curl -fsSL \
           -H 'Accept: application/vnd.github+json' \
           -H 'User-Agent: OpenPagingServer-installer' \
           "https://api.github.com/repos/${repo_path}/releases/tags/${tag}" \
           | python -c 'import json,sys; data=json.load(sys.stdin); \
             assets=[a for a in data.get("assets",[]) if a["name"].lower().endswith(".opsepm")]; \
             print(assets[0]["browser_download_url"]) if assets else exit(1)' 2>/dev/null)" \
         && curl -fL "$asset_info" -o "/var/lib/openpagingserver/endpointmodules/$(basename "$asset_info")" \
         || echo "WARN: skipping module from $repo (no .opsepm release)"; \
       else \
         echo "WARN: no tags for $repo"; \
       fi; \
     done

RUN git clone https://github.com/OpenPagingServer/assets.git /var/lib/openpagingserver/assets \
    && mkdir -p /etc/openpagingserver/trustedca \
    && curl -fsSL https://install.openpagingserver.org/rootca.crt \
         -o /etc/openpagingserver/trustedca/OpenPagingServerProject.crt \
    && curl -fsSL https://install.openpagingserver.org/trustedca-dir.md \
         -o /etc/openpagingserver/trustedca/README.md \
    || true

RUN mkdir -p /var/log/openpagingserver/endpointmodules

COPY docker-init-db.py /opt/docker-init-db.py
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
RUN chmod +x /opt/docker-entrypoint.sh

EXPOSE 80 443 5060/tcp 5060/udp 8088 8710 50010 50011

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["python", "index.py"]
