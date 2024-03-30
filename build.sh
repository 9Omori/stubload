#!/usr/bin/env bash

# exit on errors
set -o errexit

# print executed commands
set -o xtrace

meta()
{
  VERSION='0.1.4'
  FULL_VERSION='0.1.4-4'
  DESCRIPTION="a bash script that interfaces with efibootmgr to create a boot entry for the Linux kernel"
  DEPENDENCIES=('bash' 'efibootmgr' 'coreutils' 'grep')
}

fatal()
{
  local red=$'\e[1;31m'
  local none=$'\e[0m'

  echo $red"error:"$none "$1" >&2
  return 1
}

GIT_REPO='https://github.com/9Omori/stubload.git'
PKGS=(rpm git tar zstd gzip)

BUILD="$PWD/build"
OUT="$BUILD/out"

STRUCTURES=(deb/build rpmbuild rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} tar)

# root UID = 0
if (($UID > 0)); then
  sudo $0 $@
  exit
fi

[ -d "$BUILD" ] || mkdir "$BUILD"
[ -d ".git" ] || fatal "build.sh must be ran in the GitHub repository"

rpm_spec()
{
  meta
  echo >&1 \
"\
Name: stubload
Version: $VERSION
Release: 1%{?dist}
Summary: $DESCRIPTION
BuildArch: noarch
License: GPL
Source0: %{name}-%{version}.tgz

Requires: ${DEPENDENCIES[*]}

%description
%{summary}

%prep
%setup -q

%install
mkdir -p \$RPM_BUILD_ROOT/usr/bin
mkdir -p \$RPM_BUILD_ROOT/etc/efistub
mkdir -p \$RPM_BUILD_ROOT/usr/share/bash-completion/completions
mkdir -p \$RPM_BUILD_ROOT/lib/stubload/scripts
cp %{name} \$RPM_BUILD_ROOT/usr/bin/%{name}
cp completion \$RPM_BUILD_ROOT/usr/share/bash-completion/completions/%{name}
cp -a presets \$RPM_BUILD_ROOT/lib/stubload/presets
cp config.sh \$RPM_BUILD_ROOT/lib/stubload/config.sh

%clean
rm -rf \$RPM_BUILD_ROOT

%files
/usr/bin/%{name}
/usr/share/bash-completion/completions/%{name}
/lib/stubload/presets/arch
/lib/stubload/presets/arch-fallback
/lib/stubload/presets/debian
/lib/stubload/presets/fedora
/lib/stubload/presets/fedora-rescue
/lib/stubload/config.sh\
"
}

deb_control()
{
  meta
  DEB_DEPENDENCIES=$(printf ' ,%s' "${DEPENDENCIES[*]}")
  DEB_DEPENDENCIES=(${DEB_DEPENDENCIES# ,})
  echo >&1 \
"\
Package: stubload
Version: $FULL_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: basil <118671833+9Omori@users.noreply.github.com>
Description: $DESCRIPTION
Depends: ${DEB_DEPENDNECIES[*]}
Recommends: sudo\
"
}

structure()
{
  cd $BUILD

  mkdir -p "${STRUCTURES[@]}"
  mkdir "$OUT"
  
  ln -s .. source
}

dependencies()
{
  apt -y update ||
    dnf -y makecache ||
    pacman --noconfirm -Syy ||
    emerge --ask --sync
  
  for PKG in ${PKGS[@]}; do
    if (! command -v "$PKG" >/dev/null); then
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
      usr/share/bash-completions/completions \
      lib/stubload/scripts

    deb_control >./DEBIAN/control
    cp $BUILD/source/bin/stubload ./usr/bin/stubload
    cp $BUILD/source/etc/completion ./usr/share/bash-completions/completions/stubload
    cp -a $BUILD/source/lib/presets ./lib/stubload/presets
    cp $BUILD/source/lib/config.sh ./lib/stubload/config.sh

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
      lib/stubload/scripts

    cp ../source/bin/stubload ./usr/bin/stubload
    cp ../source/etc/completion ./usr/share/bash-completion/completions/stubload
    cp -a ../source/lib/presets ./lib/stubload/presets
    cp ../source/lib/config.sh ./lib/stubload/config.sh

    chmod +x ./usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub

    rm -r -f $(ls -A | sed 's/usr//; s/etc//')
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

  meta
  for pkg in $OUT/*.{rpm,deb,tzst}; do
    pkgformat="${pkg/*.}"
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
