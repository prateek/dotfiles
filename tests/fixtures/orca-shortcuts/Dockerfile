FROM node:24.12.0-bookworm-slim@sha256:7326fb2dbdce998edd72140946851be64ef4a643e8715e138ca467e8e9d92c99

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates dbus-x11 git openssh-server openssh-client python3 python3-websocket \
    libasound2 libatk-bridge2.0-0 libatspi2.0-0 libdrm2 libgbm1 libgtk-3-0 \
    libnss3 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 libxss1 \
    xauth xvfb && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /root/.ssh /workspace \
    && git -C /workspace init -q \
    && git -C /workspace -c user.name=Fixture -c user.email=fixture@example.invalid \
       commit --allow-empty -qm initial

COPY orca.AppImage /opt/orca.AppImage
RUN chmod +x /opt/orca.AppImage && cd /opt && ./orca.AppImage --appimage-extract >/dev/null \
    && rm /opt/orca.AppImage \
    && ln -s /opt/squashfs-root/resources/bin/orca-ide /usr/local/bin/orca-ide

ENV ORCA_USER_DATA_PATH=/root/.config/orca
ENV QT_X11_NO_MITSHM=1

RUN npm install --global --prefix /opt/real-agents @anthropic-ai/claude-code@2.1.292
