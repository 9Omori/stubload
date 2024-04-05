#!/bin/sh

# exit on errors
set -o errexit
# print executed commands
set -o xtrace

# build definitions
. ./build.conf

fatal()
{
  # change output to red
  local red='\e[1;31m'

  # change output to default
  local none='\e[0m'

  echo -e $red"error:"$none "$1" >&2
  return 1
}

BUILD="$PWD/build"
OUT="$BUILD/out"

# root UID = 0
if [ $(id -u) -ne 0 ]; then
  sudo $0 $@
  exit
fi

rpm_spec()
{
  echo >&1 \
"\
Name: stubload
Version: $VERSION
Release: 1%{?dist}
Summary: $DESCRIPTION
BuildArch: noarch
License: MPL-2.0
Source0: %{name}-%{version}.tgz

Requires: $DEPENDENCIES

%description
%{summary}

%prep
%setup -q

%install
mkdir -p \$RPM_BUILD_ROOT/usr/bin
mkdir -p \$RPM_BUILD_ROOT/etc/efistub
mkdir -p \$RPM_BUILD_ROOT/usr/share/bash-completion/completions
mkdir -p \$RPM_BUILD_ROOT/usr/share/man/man1
mkdir -p \$RPM_BUILD_ROOT/lib/stubload/scripts
cp %{name} \$RPM_BUILD_ROOT/usr/bin/%{name}
cp completion \$RPM_BUILD_ROOT/usr/share/bash-completion/completions/%{name}
cp -a presets \$RPM_BUILD_ROOT/lib/stubload/presets
cp config.sh \$RPM_BUILD_ROOT/lib/stubload/config.sh
cp common.sh \$RPM_BUILD_ROOT/lib/stubload/common.sh
gzip -kc man1 >\$RPM_BUILD_ROOT/usr/share/man/man1/stubload.1.gz

%clean
rm -rf \$RPM_BUILD_ROOT

%files
/usr/bin/%{name}
/usr/share/bash-completion/completions/%{name}
/usr/share/man/man1/stubload.1.gz
/lib/stubload/presets/arch
/lib/stubload/presets/arch-fallback
/lib/stubload/presets/debian
/lib/stubload/presets/fedora
/lib/stubload/presets/fedora-rescue
/lib/stubload/scripts/
/lib/stubload/config.sh
/lib/stubload/common.sh
/etc/efistub/\
"
}

deb_control()
{
  DEB_DEPENDENCIES=$(printf ' ,%s' "$DEPENDENCIES" | sed "s| ,||")
  echo >&1 \
"\
Package: stubload
Version: $FULL_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: alemontn <118671833+alemontn@users.noreply.github.com>
Description: $DESCRIPTION
Depends: $DEB_DEPENDNECIES
Recommends: man\
"
}

structure()
{
  [ -d $BUILD ] || mkdir $BUILD
  [ -d .git ] || fatal "build.sh must be ran in the GitHub repository"

  cd $BUILD

  mkdir -p $STRUCTURES
  mkdir $OUT
  
  ln -s .. source
}

dependencies()
{
  apt -y update ||
    dnf -y makecache ||
    pacman --noconfirm -Syy ||
    emerge --ask --sync
  
  for PKG in $PKGS; do
    if ! command -v "$PKG" >/dev/null; then
      apt -y install "$PKG" ||
        dnf -y install "$PKG" ||
        pacman --noconfirm -S "$PKG" ||
        emerge --ask "$PKG"
    fi
  done
}

environment()
{
  echo "-- Format: DEB"
  {
    cd $BUILD/deb/build

    mkdir -p \
      DEBIAN \
      usr/bin \
      etc/efistub \
      usr/share/bash-completion/completions \
      usr/share/man/man1 \
      lib/stubload/scripts

    deb_control >./DEBIAN/control
    cp $BUILD/source/bin/stubload ./usr/bin/stubload
    cp $BUILD/source/etc/completion ./usr/share/bash-completion/completions/stubload
    cp -a $BUILD/source/lib/presets ./lib/stubload/presets
    cp $BUILD/source/lib/config.sh ./lib/stubload/config.sh
    cp $BUILD/source/lib/common.sh ./lib/stubload/common.sh
    gzip -kc $BUILD/source/etc/man1 >./usr/share/man/man1/stubload.1.gz

    chmod +x usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub
  }

  echo "-- Format: RPM"
  {
    cd $BUILD/rpmbuild

    mkdir -p stubload-$VERSION
    ln -s stubload-$VERSION stubload

    rpm_spec >./SPECS/stubload.spec
    cp $BUILD/source/bin/stubload $BUILD/source/etc/completion stubload/
    cp -a $BUILD/source/lib/presets stubload/presets
    cp $BUILD/source/lib/config.sh stubload/config.sh
    cp $BUILD/source/lib/common.sh stubload/common.sh
    cp $BUILD/source/etc/man1 stubload/man1

    chmod +x ./stubload/stubload
    chown -R root:root stubload
    chmod 700 stubload

    tar --gzip -cf ./SOURCES/stubload-$VERSION.tgz ./stubload-$VERSION
  }

  echo "-- Format: TAR"
  {
    cd $BUILD/tar

    mkdir -p \
      usr/bin \
      etc/efistub \
      usr/share/bash-completion/completions \
      usr/share/man/man1 \
      lib/stubload/scripts

    cp ../source/bin/stubload ./usr/bin/stubload
    cp ../source/etc/completion ./usr/share/bash-completion/completions/stubload
    cp -a ../source/lib/presets ./lib/stubload/presets
    cp ../source/lib/config.sh ./lib/stubload/config.sh
    cp ../source/lib/common.sh ./lib/stubload/common.sh
    gzip -kc ../source/etc/man1 >./usr/share/man/man1/stubload.1.gz

    chmod +x ./usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub

    rm -r -f $(ls -A | sed 's/usr//; s/etc//; s/lib//')
  }
}

build_package()
{
  echo "-- Format: DEB"
  {
    cd $BUILD/deb/build
    dpkg-deb --root-owner-group --build $PWD
    mv ../*.deb $OUT
  }

  echo "-- Format: RPM"
  {
    cd $BUILD/rpmbuild
    HOME=$BUILD rpmbuild -bb SPECS/stubload.spec
    mv RPMS/noarch/*.rpm $OUT
  }

  echo "-- Format: TAR"
  {
    cd $BUILD/tar
    tar --zstd -cf stubload.tzst *
    mv *.tzst $OUT
  }

  for pkg in $OUT/*.rpm $OUT/*.deb $OUT/*.tzst; do
    pkgformat=$(echo "$pkg" | sed "s/.*\.//")
    new="stubload-$FULL_VERSION.allarch.$pkgformat"
    mv $pkg $OUT/$new
  done
}

case "$1" in
  "--all"|"-")
    structure
    dependencies
    environment
    build_package
    ;;
  "--"*)
    ${1/--}
    ;;
  "")
    fatal "insufficient arguments (use '--all'/'-' to build)"
    ;;
  *)
    fatal "unrecognised argument -- ${1##-}"
    ;;
esac
