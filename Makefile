
BINARY = \
	bin/mkluminus

MODULES = \
	bin/modules/airootfs.in \
	bin/modules/bootmode.in \
	bin/modules/image.in \
	bin/modules/pacman.in \
	bin/modules/profiledef.in \
	bin/modules/qemu.in

AIROOTFS = airootfs/*

PACKAGES = packages/*

EFIBOOT = efiboot/*

install:
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/airootfs/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/modules/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/efiboot/
	install -dm0755 $(DESTDIR)$(PREFIX)/opt/mkluminus/packages/

	install -m0755 ${BINARY} $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/
	install -m0755 ${MODULES} $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/modules/

	cp -r ${AIROOTFS} $(DESTDIR)$(PREFIX)/opt/mkluminus/airootfs/
	cp -r ${EFIBOOT} $(DESTDIR)$(PREFIX)/opt/mkluminus/efiboot/
	cp -r ${PACKAGES} $(DESTDIR)$(PREFIX)/opt/mkluminus/packages/

	ln -sf $(DESTDIR)$(PREFIX)/opt/mkluminus/bin/mkluminus /usr/sbin/mkluminus
