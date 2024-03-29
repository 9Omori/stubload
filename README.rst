stubload
========

What is it?
-----------

``stubload`` is a shell script that uses the Linux kernel’s
`EFIStub <https://www.kernel.org/doc/html/latest/admin-guide/efi-stub.html>`__
component to create a UEFI entry using
`efibootmgr <https://github.com/rhboot/efibootmgr>`__ that loads the
kernel

Why?
----

This project is made purely for fun, and for me to learn more about
shell scripting.

I cannot guarantee stability, so please use this caution.

Example usage
-------------

Create entries:

``# stubload -c``

Create entries & remove previous entries:

``# stubload -cr``

List entries:

``# stubload -l``

Edit the configuration file:

``# stubload -C``

Prerequisites
-------------

-  UEFI-compatible device
-  ``/boot`` partition with filesystem type FAT
-  EFIStub supported by kernel

Installation
------------

Stubload comes packaged in RPM (RedHat), DEB (Debian) & TZST (all)

If you want to request an additional packaging format, please create an
`issue <https://github.com/9Omori/stubload/issues>`__ with the label
‘enhancement’

I do plan to add an Arch package sometime in the near future, if anyone
would like to help with making the ‘PKGBUILD’, then also please create
an issue

After installation, you will need a configuration file in
``/etc/efistub/stubload.conf``. You can find an example of
this configuration file `here <https://github.com/9Omori/stubload/blob/main/etc/stubload.conf>`__.

Building
--------

To build for RPM/DEB/TZST, you can either:

1) Fork this repository, and run the ‘make-pkg.yml’ GitHub workflow or

2) Clone this repository and run ‘./build.sh -’

Credits
-------

`efibootmgr <https://github.com/rhboot/efibootmgr>`__ - the tool used to modify EFIvars

`bash <https://www.gnu.org/software/bash/>`__ - the scripting language used

`Linux <https://www.kernel.org/>`__ - for existing
