FROM archlinux:base-devel

# Install necessary packages like archiso and git to run
# and build Luminus
RUN pacman -Syyu --noconfirm && pacman -Syy --noconfirm --needed archiso git zsh bash

ENTRYPOINT ["zsh", ""]
