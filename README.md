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

`# stubload -crR`

List entries:

`$ stubload -l`

## Prerequisites

* A device with UEFI, not BIOS
* `/boot` partition with the FAT filesystem, not EXT4
* The kernel must have EFIStub supported

## Installation
stubload comes packaged in RPM (Fedora, openSUSE), DEB (Debian, Ubuntu) & TAR (All)

Download from: [Releases](https://github.com/9Omori/stubload/releases/latest)

## Credits
[rhboot/efibootmgr](https://github.com/rhboot/efibootmgr) - For making the tool this script uses

[The Linux kernel](https://www.kernel.org/) - For making Linux
