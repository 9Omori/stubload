#!/usr/bin/env bash
set -e

VERSION="0.1.4"
FULL_VERSION="0.1.4-1"

die()
{
  echo $'\e[1;31m'"error:" $'\e[0m'"$1" >&2
  exit 1
}

GIT_REPO='https://github.com/9Omori/stubload.git'
PKGS=(rpm git tar zstd gzip)

BUILD="$PWD/build"
OUT="$BUILD/out"

STRUCTURES=(deb/build rpmbuild rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} tar)

if (($UID)); then
  sudo $0 $@
  exit
fi

[ -d "$BUILD" ] || mkdir -v "$BUILD"
[ -d ".git" ] || die "build.sh must be ran in the GitHub repository"

structure()
{
  cd $BUILD

  mkdir -p -v "${STRUCTURES[@]}"
  mkdir -v "$OUT"
  
  ln -s .. source
}

dependencies()
{
  apt update ||
    dnf makecache ||
    pacman -Sy ||
    emerge --ask --sync
  
  for PKG in ${PKGS[@]}; do
    if (! command -v "$PKG"); then
      apt install "$PKG" ||
        dnf install "$PKG" ||
        pacman -S "$PKG" ||
        emerge --ask "$PKG"
    fi
  done
}

environment()
{
  echo "** Format: DEB"
  {
    cd $BUILD/deb/build

    mkdir -p -v \
      DEBIAN \
      usr/bin \
      etc/efistub \
      usr/share/bash-completions/completions \
      lib/stubload/scripts

    cp -v $BUILD/source/.github/build/deb/control DEBIAN/control
    cp -v $BUILD/source/bin/stubload usr/bin/stubload
    cp -v $BUILD/source/etc/completion usr/share/bash-completions/completions/stubload

    chmod +x usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub
  }

  echo "** Format: RPM"
  {
    cd $BUILD/rpmbuild

    mkdir -p -v stubload-$VERSION
    ln -s stubload-$VERSION stubload
    cp -v $BUILD/source/.github/build/rpm/stubload.spec SPECS/
    cp -v $BUILD/source/bin/stubload $BUILD/source/etc/completion stubload/

    chmod +x ./stubload/stubload
    chown -R root:root stubload
    chmod 700 stubload

    tar --gzip -cvf ./SOURCES/stubload-$VERSION.tgz ./stubload-$VERSION
  }

  echo "** Format: TAR"
  {
    cd $BUILD/tar

    mkdir -p -v \
      usr/bin \
      etc/efistub \
      usr/share/bash-completion/completions \
      lib/stubload/scripts

    cp -v ../source/bin/stubload ./usr/bin/stubload
    cp -v ../source/etc/completion ./usr/share/bash-completion/completions/stubload

    chmod +x ./usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub

    rm -r -f -v $(ls -A | sed 's/usr//; s/etc//')
  }
}

build_package()
{
  echo "** Format: DEB"
  {
    cd $BUILD/deb/build
    dpkg-deb --root-owner-group --build $PWD
    mv -v ../*.deb $OUT
  }

  echo "** Format: RPM"
  {
    cd $BUILD/rpmbuild
    HOME=$BUILD rpmbuild -bb SPECS/stubload.spec
    mv -v RPMS/noarch/*.rpm $OUT
  }

  echo "** Format: TAR"
  {
    cd $BUILD/tar
    tar --zstd -cvf stubload.tzst *
    mv -v *.tzst $OUT
  }

  for pkg in $OUT/*.{rpm,deb,tzst}; do
    pkgformat="${pkg/*.}"
    new="stubload-$FULL_VERSION.allarch.$pkgformat"
    mv -v $pkg $OUT/$new
  done

  echo "Output: "
  for OUTFILE in $OUT/*; do
    echo " * $OUTFILE"
  done
  exit 0
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
    die "insufficient arguments (use '--all'/'-' to build)"
    ;;
  *)
    die "unrecognised argument -- ${1//-}"
    ;;
esac
