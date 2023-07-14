all: dh_installnss.1

dh_installnss.1: dh_installnss
	pod2man --utf8 $< > $@

update-version:
	sed -E -i dh_installnss -e '/^our \$$VERSION = .*;$$/ s/= .*;$$/= "'"$$(dpkg-parsechangelog -S Version)"'";/'

.PHONY: all update-version
