# stubload

### What is it?
`stubload` is a script that uses the kernel's
[EFIStub](https://www.kernel.org/doc/html/latest/admin-guide/efi-stub.html) component to create a UEFI entry
that directly loads the kernel

Doing this allows for:

* Faster boot times

* Easier use of EFIStub

### Example usage
Create entries:

`# stubload -c`

`# stubload --create`

Create entries & remove previous entries:

`# stubload -cr`

`# stubload --create --remove`

List entries:

`# stubload -l`

`# stubload --list`

### Prerequisites

* UEFI device
* `boot` partition with filesystem type FAT
* EFIStub supported in kernel

### Installation
Stubload comes packaged in RPM (RedHat),
DEB (Debian) & TZST (all)

RPM (Fedora/openSUSE/etc): `rpm -ivh <package url>`

DEB (Debian/Ubuntu): `curl -LO <package url>; dpkg -i <package name>`

Other: `curl -L -o- <package url> | zstd -d | tar -xv -C /`

If you want to request an additional packaging format,
please create an [issue](https://github.com/9Omori/stubload/issues)
with the label 'enhancement'

I do plan to add an Arch package sometime in the
near future, if anyone would like to help with
making the 'PKGBUILD', then also please create
an issue

After installation, you will need a configuration file
in `/etc/efistub/stubload.conf` for stubload to function
properly

See [here](https://github.com/9Omori/stubload/blob/main/etc/stubload.conf) for an example configuration

### Credits
[efibootmgr](https://github.com/rhboot/efibootmgr)

[Linux](https://www.kernel.org/)
