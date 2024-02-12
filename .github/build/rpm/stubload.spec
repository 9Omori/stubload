Name: stubload
Version: 0.1.2
Release: 1%{?dist}
Summary: a bash script that interfaces with efibootmgr to create a boot entry for the Linux kernel
BuildArch: noarch

License: GPL
Source0: %{name}-%{version}.tgz

Requires: bash efibootmgr coreutils grep sed
Recommends: sudo

%description
%{summary}

%prep
%setup -q

%install
mkdir -p $RPM_BUILD_ROOT/usr/bin $RPM_BUILD_ROOT/etc/efistub $RPM_BUILD_ROOT/usr/share/bash-completion/completions
cp %{name}.sh $RPM_BUILD_ROOT/usr/bin/%{name}
cp completion.sh $RPM_BUILD_ROOT/usr/share/bash-completion/completions/%{name}

%clean
rm -rf $RPM_BUILD_ROOT

%files
/usr/bin/%{name}
/usr/share/bash-completion/completions/%{name}
