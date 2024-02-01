# stubload

## What is it?
stubload is a bash script that utilises the Linux kernel's 'EFIStub'

The goal of this script is to:

* Remove the need for bootloaders

* Speed up boot times by directly loading the kernel

* Make the experience of using EFIStub less of a hassle

## Example usage
Create entries:

`# stubload -c`

Create entries & remove previous entries:

`# stubload -cr`

List entries:

`$ stubload -l`

## Installation
One-line install:

`$ curl https://raw.githubusercontent.com/9Omori/stubload/main/install.sh | sudo bash`

## Credits
[rhboot/efibootmgr](https://github.com/rhboot/efibootmgr) - For making the tool this script uses

[The Linux kernel](https://www.kernel.org/) - For making Linux
