# stubload

### What is it?
`stubload` is a script that uses the kernel's
[EFIStub](https://www.kernel.org/doc/html/latest/admin-guide/efi-stub.html) component to create a UEFI entry
that directly loads the kernel

By doing this, you allow:

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

RedHat: `dnf install <package url>`

openSUSE: `rpm -ivh <package url>`

Debian: `dpkg `

If you want to request an additional packaging format,
please create an [Issue](https://github.com/9Omori/stubload/issues)
with the label 'enhancement'

After installation, you will need a configuration file
in `/etc/efistub/stubload.conf` for stubload to function
properly

See [here](https://github.com/9Omori/stubload/blob/main/stubload.conf) to see an example configuration

### Credits
[efibootmgr](https://github.com/rhboot/efibootmgr)

[Linux](https://www.kernel.org/)
