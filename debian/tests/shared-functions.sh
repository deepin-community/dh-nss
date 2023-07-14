# shellcheck shell=dash

check_line () {
	local db="$1"
	local expected_services="$2"

	local expected_line="$db:    $expected_services"
	local new_line

	if ! new_line=$(grep "^$1:" /etc/nsswitch.conf) ; then
		echo "ERROR: DB $db not found in /etc/nsswitch.conf" >&2
		exit 2
	fi

	local num_db_lines
	num_db_lines="$(echo "$new_line" | wc -l)"
	if [ "$num_db_lines" -ne 1 ] ; then
		echo "ERROR: Too many lines for DB $db: $num_db_lines" >&2
		exit 3
	fi

	if [ "$new_line" != "$expected_line" ] ; then
		echo "ERROR: Wrong db line in /etc/nsswitch.conf" >&2
		echo "   found: \`$new_line'" >&2
		echo "expected: \`$expected_line'" >&2
		exit 4
	fi

	echo "OK"
}


setup_pkg () {
	local pkgname=$1
	local testname=$2

	mkdir debian

	cat <<EOF > debian/control
Source: $pkgname
Section: devel
Priority: optional
Maintainer: Test User <test@example.org>
Rules-Requires-Root: no
Build-Depends: debhelper-compat (= 13), dh-sequence-installnss
Standards-Version: 4.6.1

Package: $pkgname
Architecture: all
Description: Test package for dh-nss ($testname)
 Test package for dh-nss ($testname)
EOF

	cat <<EOF > debian/rules
#!/usr/bin/make -f
%:
	dh \$@
EOF
	chmod +x debian/rules
}

build_pkg () {
	pkgname="$1"
	pkgversion="$2"
	nss_lines="$3"

	echo "$nss_lines" > debian/nss

	cat <<EOF > debian/changelog
$pkgname ($pkgversion) unstable; urgency=medium

  * Test build

 -- Test User <test@example.org>  Sun, 06 Aug 2022 11:22:33 +0200
EOF

	dpkg-buildpackage --no-sign --build=binary
}

NSSWITCH_CONF="
# /etc/nsswitch.conf

passwd:         files
group:          files
shadow:         files
gshadow:        files

hosts:    files dns
networks: files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis"
