
BINARY = \
	bin/mkluminus

MODULES = \
	bin/modules/airootfs.in \
	bin/modules/bootmode.in \
	bin/modules/image.in \
	bin/modules/pacman.in \
	bin/modules/profiledef.in \
	bin/modules/qemu.in


install:
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/modules/

	install -m0755 ${BINARY} $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/
	install -m0755 ${MODULES} $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/modules/

	ln -s $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/mkluminus /usr/sbin/mkluminus
