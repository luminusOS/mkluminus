FROM archlinux:base-devel

# Install necessary packages like archiso and git to run
# and build Luminus
RUN pacman -Syy --noconfirm --needed archiso git zsh bash

RUN ln -s /opt/mkluminus/bin/mkluminus /usr/sbin/mkluminus
COPY . /opt/mkluminus/

ENTRYPOINT ["zsh", ""]
