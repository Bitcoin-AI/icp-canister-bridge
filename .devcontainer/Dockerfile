FROM mcr.microsoft.com/devcontainers/base:jammy

RUN sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)" && chmod a+x /usr/local/bin/dfx

RUN wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb && dpkg -i libssl1.1_1.1.0g-2ubuntu4_amd64.deb

RUN wget -O /usr/local/bin/vessel https://github.com/dfinity/vessel/releases/download/v0.6.4/vessel-linux64 && chmod a+x /usr/local/bin/vessel

# Install the latest version of Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get install -y nodejs
