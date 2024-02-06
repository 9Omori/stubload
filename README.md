# stubload

## What?
`stubload` is a bash script that interfaces with `efibootmgr` to create a boot entry for the Linux kernel

## Why?

The main goals of `stubload` are:

* Speed up boot times & remove the need for a bootloader

* Make using EFIStub easier

## Example usage
Create entries:

`# stubload -c`

Create entries & remove previous entries:

`# stubload -cr`

List entries:

`$ stubload -l`

## Prerequisites

* A UEFI device
* `/boot` partition with the FAT filesystem
* A kernel with EFIStub support

## Installation
Fedora:

`$ sudo dnf install <URL>.rpm`

Debian:

`$ curl -L <URL>.rpm | sudo dpkg -i`

Manual:
`$ curl -L <URL>.tzst | zstd -d | sudo tar -x -C /`

[Releases](https://github.com/9Omori/stubload/releases/latest)

After installation, edit `/etc/efistub/stubload.conf` to properly configure stubload

## Credits
[efibootmgr](https://github.com/rhboot/efibootmgr)

[Linux](https://www.kernel.org/)
