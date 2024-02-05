Name: stubload
Version: 0.0.1
Release: 1%{?dist}
Summary: a bash script that interfaces with efibootmgr to create a boot entry for the Linux kernel
BuildArch: noarch

License: GPL
Source0: %{name}-%{version}.tgz

Requires: bash efibootmgr

%description
%{summary}

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_bindir} $RPM_BUILD_ROOT/%{_sysconfdir}/efistub
cp %{name}.sh $RPM_BUILD_ROOT/%{_bindir}/%{name}
cp %{name}.conf $RPM_BUILD_ROOT/etc/efistub/

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{_bindir}/%{name}
%{_sysconfdir}/efistub/%{name}.conf
