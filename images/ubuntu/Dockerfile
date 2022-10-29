ARG DISTRO=ubuntu
ARG VARIANT=jammy

FROM ${DISTRO}:${VARIANT}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

COPY setup.sh /usr/local/bin/setup

RUN /usr/local/bin/setup "${USERNAME}" "${USER_UID}" "${USER_GID}" \
 && rm -rf /usr/local/bin/setup

USER ${USERNAME}
