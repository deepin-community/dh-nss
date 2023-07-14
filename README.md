# `dh_installnss` - enable NSS services

`dh_installnss` is a debhelper program that is responsible for injecting
NSS (Name Service Switch) services into `/etc/nsswitch.conf`.

## Example

An example `debian/nss` file could look like this:

    hosts before=dns mdns4
    hosts before=mdns4 mdns4_minimal [NOTFOUND=return]
    hosts remove-only mdns    # In case the user manually added it

After the installation of this package, the original configuration of
the `hosts` database in `/etc/nsswitch.conf` will change from:

    hosts:    files dns

to:

    hosts:    files mdns4_minimal [NOTFOUND=return] mdns4 dns

## Documentation

Detailed documentation can be found in `dh_installnss(1)`.
