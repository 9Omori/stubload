# stubload

### What is it?
`stubload` utilizes the [EFIStub](https://www.kernel.org/doc/html/latest/admin-guide/efi-stub.html) kernel component

EFIStub allows the user to directly load the kernel from the UEFI

The main goals of `stubload` are:

* Speed up boot times & remove the need for a bootloader

* Make using EFIStub easier

* For the fun of writing scripts

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

* A UEFI device
* `/boot` partition with the FAT filesystem
* A kernel with EFIStub support

### Installation
[Releases](https://github.com/9Omori/stubload/releases/latest)

Fedora:

`# dnf install *.rpm`

Debian:

`# curl -L *.deb | dpkg -i`

Manual:

`# curl -L *.tzst | zstd -d | tar -x -C /`

After installation, you must create `/etc/efistub/stubload.conf` and fill it out

See [here](https://github.com/9Omori/stubload/blob/main/stubload.conf) to see an example configuration

### Credits
[efibootmgr](https://github.com/rhboot/efibootmgr)

[Linux](https://www.kernel.org/)
