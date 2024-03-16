#!/usr/bin/env -S bash -e

VERSION="0.1.3"
FULL_VERSION="0.1.3-7"

die()
{
  echo $'\e[1;31m'"error:" $'\e[0m'"$1" >&2
  exit 1
}

GIT_REPO='https://github.com/9Omori/stubload.git'
PKGS=(rpm git tar zstd gzip)

BUILD="$PWD/build"
OUT="$BUILD/out"

echo "Running sanity check:"
{
  if ! ([ "$UID" = '0' ] && [ "$USER" == "root" ]); then
    sudo $0 ${@/$0}
  fi

  if ! (command -v apt >/dev/null); then
    die "apt not found, build.sh must be ran on a Debian-based distro"
  fi
}

echo "Initialising:"
{
  echo "$BUILD"
  mkdir -v $BUILD
  cd $BUILD
}

echo "Setting up structure:"
{
  cd $BUILD
  echo "$PWD"

  mkdir -p -v \
    ./deb/build/ \
    ./rpmbuild/ ./rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} \
    ./tar/
  mkdir -v $OUT
}

echo "Installing dependencies:"
{
  apt update
  apt install -y "${PKGS[@]}"
}

echo "Cloning repository:"
{
  cd $BUILD
  git clone "$GIT_REPO" ./source

  cd $BUILD/deb
  ln -s ../source .
}

echo "Setting up environment:"
{
  echo "Format: DEB"
  {
    cd $BUILD/deb/build

    mkdir -p -v \
      DEBIAN \
      usr/bin \
      etc/efistub \
      usr/share/bash-completions/completions \
      lib/stubload/scripts

    mv -v $BUILD/source/.github/build/deb/control DEBIAN/control
    cp -v $BUILD/source/bin/stubload.sh usr/bin/stubload
    cp -v $BUILD/source/etc/completion.sh usr/share/bash-completions/stubload

    chmod +x usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub
  }

  echo "Format: RPM"
  {
    cd $BUILD/rpmbuild

    mkdir -p -v stubload-$VERSION
    ln -s stubload-$VERSION stubload
    mv -v $BUILD/source/.github/build/rpm/stubload.spec SPECS/
    cp -v $BUILD/source/bin/stubload.sh $BUILD/source/etc/completion.sh stubload/

    chmod +x ./stubload/stubload.sh
    chown -R root:root stubload
    chmod 700 stubload

    tar --gzip -cvf ./SOURCES/stubload-$VERSION.tgz ./stubload-$VERSION
  }

  echo "Format: TAR"
  {
    cd $BUILD/tar

    mkdir -p -v \
      usr/bin \
      etc/efistub \
      usr/share/bash-completion/completions \
      lib/stubload/scripts

    cp -v ../source/bin/stubload.sh ./usr/bin/stubload
    cp -v ../source/etc/completion.sh ./usr/share/bash-completion/completions/stubload

    chmod +x ./usr/bin/stubload
    chown -R root:root etc/efistub
    chmod 700 etc/efistub

    rm -r -f -v $(ls -A | sed 's/usr//; s/etc//')
  }
}

echo "Build package:"
{
  echo "Format: DEB"
  {
    cd $BUILD/deb/build
    dpkg-deb --root-owner-group --build $PWD
    mv -v ../*.deb $OUT
  }

  echo "Format: RPM"
  {
    cd $BUILD/rpmbuild
    HOME=$BUILD rpmbuild -bb SPECS/stubload.spec
    mv -v RPMS/noarch/*.rpm $OUT
  }

  echo "Format: TAR"
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

  echo "Output: " $OUT/*
}