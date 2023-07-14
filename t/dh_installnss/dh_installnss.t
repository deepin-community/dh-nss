#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use lib dirname(dirname(abs_path(__FILE__)));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 1);

my $test_dir = abs_path(dirname(__FILE__));
my $dpkg_root = "debian/foo";

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
	debian/changelog
	debian/control
	debian/foo-after1.nss
	debian/foo-after2.nss
	debian/foo-before1.nss
	debian/foo-before2.nss
	debian/foo-empty1.nss
	debian/foo-empty2.nss
	debian/foo-example.nss
	debian/foo-first1.nss
	debian/foo-first2.nss
	debian/foo-first3.nss
	debian/foo-last1.nss
	debian/foo-last2.nss
	debian/foo-last3.nss
	debian/foo-multidb1.nss
	debian/foo-newdb1.nss
	debian/foo-newdb2.nss
	debian/foo-newdb3.nss
	debian/foo-other.nss
	debian/foo-remove-only1.nss
	debian/foo-skip.nss
	debian/foo-substring.nss
));

each_compat_subtest {
	make_path(qw(debian/foo debian/foo/etc));
	ok(run_dh_tool("dh_installnss"));

	$ENV{"DPKG_ROOT"} = "$dpkg_root";
	$ENV{"DPKG_MAINTSCRIPT_PACKAGE_INSTCOUNT"} = 0;

	subtest "skips installation if no /etc/nsswitch.conf" => sub {
		unlink("$dpkg_root/etc/nsswitch.conf");
		exec_script_ok("foo-first1", "preinst", "install");
		exec_script_ok("foo-first1", "postinst", "configure");
		ok(!-e "$dpkg_root/etc/nsswitch.conf");
	};

	subtest "respects skip-if-present" => sub {
		place_nsswitch_file("hosts", "files other2 dns");
		exec_script_ok("foo-skip", "preinst", "install");
		exec_script_ok("foo-skip", "postinst", "configure");
		is(db_line("hosts"), "hosts: foo2 files other2 dns");
		exec_script_ok("foo-skip", "postrm", "remove");
		is(db_line("hosts"), "hosts: files other2 dns");
	};

	subtest "position=first" => sub {
		subtest "adds in first position" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo files other2 dns");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds in first position (in presence of comments)" => sub {
			place_nsswitch_file("hosts", "files other2 dns # comment");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo files other2 dns # comment");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns # comment");
		};

		subtest "adds in first position (in presence of service in comment)" => sub {
			place_nsswitch_file("hosts", "files other2 dns # foo in comment");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo files other2 dns # foo in comment");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns # foo in comment");
		};

		subtest "adds in first position (with action)" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-first2", "preinst", "install");
			exec_script_ok("foo-first2", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo [NOTFOUND=return] files other2 dns");
			exec_script_ok("foo-first2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds in first position (multiple times)" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-first3", "preinst", "install");
			exec_script_ok("foo-first3", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo2 [NOTFOUND=return] foo2 files other2 dns");
			exec_script_ok("foo-first3", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "does not add if already present in line (service name)" => sub {
			place_nsswitch_file("hosts", "files foo dns");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo dns");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "does not add if already present in line (service first)" => sub {
			place_nsswitch_file("hosts", "foo files dns");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo files dns");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "does not add if already present in line (service last)" => sub {
			place_nsswitch_file("hosts", "files dns foo");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files dns foo");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "does not add if already present in line (service last before comment)" => sub {
			place_nsswitch_file("hosts", "files dns foo# comment");
			exec_script_ok("foo-first1", "preinst", "install");
			exec_script_ok("foo-first1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files dns foo# comment");
			exec_script_ok("foo-first1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns# comment");
		};

		subtest "does not add if already present in line (service name with action)" => sub {
			place_nsswitch_file("hosts", "files foo [NOTFOUND=return] dns");
			exec_script_ok("foo-first2", "preinst", "install");
			exec_script_ok("foo-first2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo [NOTFOUND=return] dns");
			exec_script_ok("foo-first2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "does not if already present in line (service name without action)" => sub {
			place_nsswitch_file("hosts", "files foo dns");
			exec_script_ok("foo-first2", "preinst", "install");
			exec_script_ok("foo-first2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo dns");
			exec_script_ok("foo-first2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};
	};

	subtest "position=last" => sub {
		subtest "adds in last position" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-last1", "preinst", "install");
			exec_script_ok("foo-last1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo");
			exec_script_ok("foo-last1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds in last position (with action)" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-last2", "preinst", "install");
			exec_script_ok("foo-last2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo [NOTFOUND=return]");
			exec_script_ok("foo-last2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds in last position (multiple times)" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-last3", "preinst", "install");
			exec_script_ok("foo-last3", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo2 foo2 [NOTFOUND=return]");
			exec_script_ok("foo-last3", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds before a comment" => sub {
			place_nsswitch_file("hosts", "files other2 dns #a long comment");
			exec_script_ok("foo-last1", "preinst", "install");
			exec_script_ok("foo-last1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo #a long comment");
			exec_script_ok("foo-last1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns #a long comment");
		};

		subtest "adds before a comment (no space)" => sub {
			place_nsswitch_file("hosts", "files other2 dns#short comment");
			exec_script_ok("foo-last1", "preinst", "install");
			exec_script_ok("foo-last1", "postinst", "configure");
			# The script unconditionally adds a space before the comment.
			is(db_line("hosts"), "hosts: files other2 dns foo #short comment");
			exec_script_ok("foo-last1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns #short comment");
		};
	};

	subtest "position=before" => sub {
		subtest "adds before another" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-before1", "preinst", "install");
			exec_script_ok("foo-before1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 foo dns");
			exec_script_ok("foo-before1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds before another (in presence of comments)" => sub {
			place_nsswitch_file("hosts", "files other2 dns # comment");
			exec_script_ok("foo-before1", "preinst", "install");
			exec_script_ok("foo-before1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 foo dns # comment");
			exec_script_ok("foo-before1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns # comment");
		};

		subtest "adds before another with action" => sub {
			place_nsswitch_file("hosts", "files other2 dns [NOTFOUND=return]");
			exec_script_ok("foo-before1", "preinst", "install");
			exec_script_ok("foo-before1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 foo dns [NOTFOUND=return]");
			exec_script_ok("foo-before1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns [NOTFOUND=return]");
		};

		subtest "does not add before another if missing" => sub {
			place_nsswitch_file("hosts", "files other2");
			exec_script_ok("foo-before1", "preinst", "install");
			exec_script_ok("foo-before1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2");
			exec_script_ok("foo-before1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2");
		};

		subtest "does not add if another missing (but in comment)" => sub {
			place_nsswitch_file("hosts", "files other2 # dns");
			exec_script_ok("foo-before1", "preinst", "install");
			exec_script_ok("foo-before1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 # dns");
			exec_script_ok("foo-before1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 # dns");
		};

		subtest "adds before another (multiple possibilites, one found)" => sub {
			place_nsswitch_file("hosts", "files resolve other2");
			exec_script_ok("foo-before2", "preinst", "install");
			exec_script_ok("foo-before2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo resolve other2");
			exec_script_ok("foo-before2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files resolve other2");
		};

		subtest "adds before another (multiple possibilites, same order)" => sub {
			place_nsswitch_file("hosts", "files dns resolve other2");
			exec_script_ok("foo-before2", "preinst", "install");
			exec_script_ok("foo-before2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo dns resolve other2");
			exec_script_ok("foo-before2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns resolve other2");
		};

		subtest "adds before another (multiple possibilites, inverted order)" => sub {
			place_nsswitch_file("hosts", "files resolve other2 dns");
			exec_script_ok("foo-before2", "preinst", "install");
			exec_script_ok("foo-before2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo resolve other2 dns");
			exec_script_ok("foo-before2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files resolve other2 dns");
		};

		subtest "adds before another (multiple possibilites, with action)" => sub {
			place_nsswitch_file("hosts", "files resolve [!NOTFOUND=return] other2");
			exec_script_ok("foo-before2", "preinst", "install");
			exec_script_ok("foo-before2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo resolve [!NOTFOUND=return] other2");
			exec_script_ok("foo-before2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files resolve [!NOTFOUND=return] other2");
		};
	};

	subtest "position=after" => sub {
		subtest "adds after another" => sub {
			place_nsswitch_file("hosts", "files other2 dns");
			exec_script_ok("foo-after1", "preinst", "install");
			exec_script_ok("foo-after1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo");
			exec_script_ok("foo-after1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns");
		};

		subtest "adds after another (in presence of comments)" => sub {
			place_nsswitch_file("hosts", "files other2 dns # a comment");
			exec_script_ok("foo-after1", "preinst", "install");
			exec_script_ok("foo-after1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 dns foo # a comment");
			exec_script_ok("foo-after1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 dns # a comment");
		};

		subtest "adds after another with action" => sub {
			place_nsswitch_file("hosts", "dns [NOTFOUND=return] other2 files");
			exec_script_ok("foo-after1", "preinst", "install");
			exec_script_ok("foo-after1", "postinst", "configure");
			is(db_line("hosts"), "hosts: dns [NOTFOUND=return] foo other2 files");
			exec_script_ok("foo-after1", "postrm", "remove");
			is(db_line("hosts"), "hosts: dns [NOTFOUND=return] other2 files");
		};

		subtest "does not add after another if missing (but in comment)" => sub {
			place_nsswitch_file("hosts", "files other2 # dns");
			exec_script_ok("foo-after1", "preinst", "install");
			exec_script_ok("foo-after1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2 # dns");
			exec_script_ok("foo-after1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2 # dns");
		};

		subtest "does not add after another if missing" => sub {
			place_nsswitch_file("hosts", "files other2");
			exec_script_ok("foo-after1", "preinst", "install");
			exec_script_ok("foo-after1", "postinst", "configure");
			is(db_line("hosts"), "hosts: files other2");
			exec_script_ok("foo-after1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files other2");
		};

		subtest "adds after another (multiple possibilites)" => sub {
			place_nsswitch_file("hosts", "files resolve other2");
			exec_script_ok("foo-after2", "preinst", "install");
			exec_script_ok("foo-after2", "postinst", "configure");
			is(db_line("hosts"), "hosts: files foo resolve other2");
			exec_script_ok("foo-after2", "postrm", "remove");
			is(db_line("hosts"), "hosts: files resolve other2");
		};
	};

	subtest "position=remove-only" => sub {
		subtest "does not add remove-only services" => sub {
			place_nsswitch_file("hosts", "files dns");
			exec_script_ok("foo-remove-only1", "preinst", "install");
			exec_script_ok("foo-remove-only1", "postinst", "configure");
			is(db_line("hosts"), "hosts: foo files dns");
			exec_script_ok("foo-remove-only1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes both added and already present services" => sub {
			place_nsswitch_file("hosts", "foo files resolve dns");
			exec_script_ok("foo-remove-only1", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};
	};

	subtest "addition" => sub {
		subtest "skips if any service is already mentioned in a target database (1)" => sub {
			place_nsswitch_file("shadow", "files foo dns");
			exec_script_ok("foo-multidb1", "preinst", "install");
			exec_script_ok("foo-multidb1", "postinst", "configure");
			is(db_line("shadow"), "shadow: files foo dns");
			exec_script_ok("foo-multidb1", "postrm", "remove");
			is(db_line("shadow"), "shadow: files dns");
		};

		subtest "skips if any service is already mentioned in a target database (2)" => sub {
			place_nsswitch_file("passwd", "baz files");
			exec_script_ok("foo-multidb1", "preinst", "install");
			exec_script_ok("foo-multidb1", "postinst", "configure");
			is(db_line("passwd"), "passwd: baz files");
			exec_script_ok("foo-multidb1", "postrm", "remove");
			is(db_line("passwd"), "passwd: files");
		};

		subtest "adds if the service is mentioned in an unrelated database" => sub {
			place_nsswitch_file("passwd", "files foo");
			is(db_line("shadow"), "shadow: files");
			exec_script_ok("foo-multidb1", "preinst", "install");
			exec_script_ok("foo-multidb1", "postinst", "configure");
			is(db_line("shadow"), "shadow: foo files foo2");
			is(db_line("passwd"), "passwd: files foo baz");
			exec_script_ok("foo-multidb1", "postrm", "remove");
			is(db_line("shadow"), "shadow: files");
			is(db_line("passwd"), "passwd: files foo");
		};
	};

	subtest "removal" => sub {
		subtest "succeeds if service has already been removed" => sub {
			place_nsswitch_file("hosts", "files dns");
			exec_script_ok("foo-other", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes all instances of service (consecutive 1)" => sub {
			place_nsswitch_file("hosts", "files foo foo [NOTFOUND=return] foo dns");
			exec_script_ok("foo-other", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes all instances of service (consecutive 2)" => sub {
			place_nsswitch_file("hosts", "files foo [NOTFOUND=return] foo foo dns");
			exec_script_ok("foo-other", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes all instances of service (split 1)" => sub {
			place_nsswitch_file("hosts", "files foo [NOTFOUND=return] foo dns foo");
			exec_script_ok("foo-other", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes all instances of service (split 2)" => sub {
			place_nsswitch_file("hosts", "foo [NOTFOUND=return] files foo [!UNAVAIL=return] foo dns");
			exec_script_ok("foo-other", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes all instances of service (also during purge)" => sub {
			place_nsswitch_file("hosts", "files foo foo [NOTFOUND=return] foo dns");
			exec_script_ok("foo-other", "postrm", "purge");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes services with substring names" => sub {
			place_nsswitch_file("hosts", "foo_extra files foo dns");
			exec_script_ok("foo-substring", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns");
		};

		subtest "removes services with substring names (in presence of comments)" => sub {
			place_nsswitch_file("hosts", "foo_extra files foo dns# comment: foo is ok");
			exec_script_ok("foo-substring", "postrm", "remove");
			is(db_line("hosts"), "hosts: files dns# comment: foo is ok");
		};
	};

	subtest "position=database-add" => sub {
		subtest "adds a database if not already present (without service)" => sub {
			place_nsswitch_file();
			is(num_occurrences("mydb", dbs()), 0);
			exec_script_ok("foo-newdb1", "preinst", "install");
			exec_script_ok("foo-newdb1", "postinst", "configure");
			is(db_line("mydb"), "mydb: ");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb1", "postrm", "remove");
			is(num_occurrences("mydb", dbs()), 0);
		};

		subtest "does not add the database if already present (without service)" => sub {
			place_nsswitch_file();
			is(num_occurrences("mydb", dbs()), 0);
			# first install
			exec_script_ok("foo-newdb1", "preinst", "install");
			exec_script_ok("foo-newdb1", "postinst", "configure");
			is(db_line("mydb"), "mydb: ");
			is(num_occurrences("mydb", dbs()), 1);
			# second install
			exec_script_ok("foo-newdb1", "preinst", "install");
			exec_script_ok("foo-newdb1", "postinst", "configure");
			is(db_line("mydb"), "mydb: ");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb1", "postrm", "remove");
			is(num_occurrences("mydb", dbs()), 0);
		};

		subtest "adds a database if not already present (with service)" => sub {
			place_nsswitch_file();
			is(num_occurrences("mydb", dbs()), 0);
			exec_script_ok("foo-newdb2", "preinst", "install");
			exec_script_ok("foo-newdb2", "postinst", "configure");
			is(db_line("mydb"), "mydb: foo "); # TODO: fix trailing space in v2
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb2", "postrm", "remove");
			is(num_occurrences("mydb", dbs()), 0);
		};

		subtest "does not add the database if already present (with service)" => sub {
			place_nsswitch_file();
			is(num_occurrences("mydb", dbs()), 0);
			# first install
			exec_script_ok("foo-newdb2", "preinst", "install");
			exec_script_ok("foo-newdb2", "postinst", "configure");
			is(db_line("mydb"), "mydb: foo "); # TODO: fix trailing space in v2
			is(num_occurrences("mydb", dbs()), 1);
			# second install
			exec_script_ok("foo-newdb2", "preinst", "install");
			exec_script_ok("foo-newdb2", "postinst", "configure");
			is(db_line("mydb"), "mydb: foo "); # TODO: fix trailing space in v2
			is(num_occurrences("mydb", dbs()), 1);
			# removal
			exec_script_ok("foo-newdb2", "postrm", "remove");
			is(num_occurrences("mydb", dbs()), 0);
		};
	};

	subtest "position=detabase-require" => sub {
		subtest "adds a service to the the database if already present" => sub {
			place_nsswitch_file("mydb", "other");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb3", "preinst", "install");
			exec_script_ok("foo-newdb3", "postinst", "configure");
			is(db_line("mydb"), "mydb: bar other");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb3", "postrm", "remove");
			is(db_line("mydb"), "mydb: other");
			is(num_occurrences("mydb", dbs()), 1);
		};

		subtest "does not add a service if the database is missing" => sub {
			place_nsswitch_file();
			is(num_occurrences("mydb", dbs()), 0);
			exec_script_ok("foo-newdb3", "preinst", "install");
			exec_script_ok("foo-newdb3", "postinst", "configure");
			is(num_occurrences("mydb", dbs()), 0);
			exec_script_ok("foo-newdb3", "postrm", "remove");
			is(num_occurrences("mydb", dbs()), 0);
		};

		subtest "does not remove the database during package removal" => sub {
			place_nsswitch_file("mydb", " ");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb3", "preinst", "install");
			exec_script_ok("foo-newdb3", "postinst", "configure");
			is(db_line("mydb"), "mydb: bar ");
			is(num_occurrences("mydb", dbs()), 1);
			exec_script_ok("foo-newdb3", "postrm", "remove");
			is(db_line("mydb"), "mydb: ");
			is(num_occurrences("mydb", dbs()), 1);
		};
	};

	subtest "validation" => sub {
		subtest "does not add debhelper snippets if .nss is empty" => sub {
			my ($postinst_path) = find_script("foo-empty1", "postinst");
			my ($postrm_path) = find_script("foo-empty1", "postrm");
			is($postinst_path, undef);
			is($postrm_path, undef);
		};

		subtest "does not add debhelper snippets if .nss is empty (with comments)" => sub {
			my ($postinst_path) = find_script("foo-empty2", "postinst");
			my ($postrm_path) = find_script("foo-empty2", "postrm");
			is($postinst_path, undef);
			is($postrm_path, undef);
		};
	};

	subtest "example in docs" => sub {
		place_nsswitch_file("hosts", "files dns");
		exec_script_ok("foo-example", "preinst", "install");
		exec_script_ok("foo-example", "postinst", "configure");
		is(db_line("hosts"), "hosts: files mdns4_minimal [NOTFOUND=return] mdns4 dns");
		exec_script_ok("foo-example", "postrm", "remove");
		is(db_line("hosts"), "hosts: files dns");
	};

	ok(run_dh_tool('dh_clean'));
};

sub place_nsswitch_file {
	my ($db, $line) = @_;
	my $template_file = "$test_dir/nsswitch.conf.template";
	my $conf_file = "debian/foo/etc/nsswitch.conf";

	my $fd;
	open($fd, '<', $template_file) or error("open($template_file): $!");
	read($fd, my $conf, -s $fd);
	close($fd);

	if ($db && $line) {
		my $db_line_re = "^$db:.*\$";
		my $newline = "$db:   $line";
		if ($conf =~ /$db_line_re/m) {
			$conf =~ s/$db_line_re/$newline/m;
		} else {
			$conf .= "\n$newline\n";
		}
	}

	open($fd, '>', $conf_file) or error("open($conf_file): $!");
	print($fd $conf);
	close($fd);
}

sub exec_script_ok {
	is(exec_script(@_), 0);
}

sub exec_script {
	my ($package, $script, @args) = @_;
	my ($script_path) = find_script($package, $script);
	(defined $script_path && $script_path ne "") or error("No maintscript of type $script found");
	system("sh", "-e", $script_path, @args);
	return $? >> 8;
}

sub db_line {
	my ($db) = @_;

	my @lines = nsswitch_file_lines();

	my $db_line_re = "^$db:";
	my ($line) = grep({ m/$db_line_re/ } @lines);
	$line //= "";
	# Normalize spaces to simplify comparison.
	$line =~ s/\s+/ /g;

	return $line;
}

sub dbs {
	my @lines = nsswitch_file_lines();

	my @dbs = ();
	foreach my $line (@lines) {
		my ($db) = $line =~ m/^([a-zA-Z]+):/g;
		push @dbs, $db if $db;
	}

	return @dbs;
}

sub nsswitch_file_lines {
	open(my $fd, '<', "$dpkg_root/etc/nsswitch.conf");
	my @lines = @{readlines($fd)};
	close($fd);

	return @lines;
}

sub num_occurrences {
	my ($item, @array) = @_;

	return scalar grep({$_ eq $item} @array);
}
