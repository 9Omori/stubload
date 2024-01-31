# stubload

## What is it?
stubload is a bash script that utilises the Linux kernel's 'EFIStub'

The goal of this script is to:

* Remove the need for bootloaders

* Speed up boot times by directly loading the kernel

* Make the experience of using EFIStub less of a hassle

## Installation
One-line install:

`# curl -L https://raw.githubusercontent.com/9Omori/stubload/master/stubload.sh -o /usr/local/bin/stubload`

If you get: `bash: stubload: Permission denied`, then make the script executable:

### `# chmod + /usr/local/bin/stubload`

## Credits
[rhboot/efibootmgr](https://github.com/rhboot/efibootmgr) - For making the tool this script uses

[The Linux kernel](https://www.kernel.org/) - For making Linux
