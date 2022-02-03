FROM archlinux

# Use faster mirror to speed up the image build
RUN echo 'Server = http://linorg.usp.br/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# Install necessary packages
RUN --mount=type=cache,sharing=locked,target=/var/cache/pacman \
    pacman -Suy --noconfirm --needed archiso git

# Prepare workdir
RUN mkdir luminus
COPY . /luminus
WORKDIR /luminus

# Make build.sh executable and start it
RUN chown root build.sh
RUN chmod a+x build.sh
CMD ["/luminus/build.sh", "-d"]