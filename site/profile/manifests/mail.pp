class profile::mail::sender(
  String $relayhost_ip,
  String $origin,
) {
  class { 'postfix':
    inet_protocols   => 'ipv4',
    relayhost        => $relayhost_ip,
    myorigin         => $origin,
    satellite        => true,
    manage_mailx     => false,
    manage_conffiles => false,
  }

  postfix::config { 'authorized_submit_users':
    ensure => present,
    value  => 'root, slurm',
  }
}

class profile::mail::relayhost(
  String $origin,
) {

  class { 'profile::mail::dkim':
    domain_name => $origin,
  }

  $cidr = profile::getcidr()
  $interface = split($::interfaces, ',')[0]
  $ipaddress = $::networking['interfaces'][$interface]['ip']

  class { 'postfix':
    inet_interfaces  => "127.0.0.1, ${ipaddress}",
    inet_protocols   => 'ipv4',
    mynetworks       => "127.0.0.0/8, ${cidr}",
    myorigin         => $origin,
    mta              => true,
    relayhost        => 'direct',
    smtp_listen      => 'all',
    manage_mailx     => false,
    manage_conffiles => false,
  }

  postfix::config { 'authorized_submit_users':
    ensure => present,
    value  => 'root, slurm',
  }
}

class profile::mail::dkim (
  String $domain_name
) {
  $cidr = profile::getcidr()

  package { 'opendkim':
    ensure  => 'installed',
    require => Yumrepo['epel'],
  }

  file { '/etc/opendkim/keys/default.private':
    user  => 'opendkim',
    group => 'opendkim',
    mode  => '0600',
  }

  service { 'opendkim':
    ensure  => running,
    enable  => true,
    require => [
      Package['opendkim'],
      File['/etc/opendkim/keys/default.private'],
    ],
  }

  file_line { 'opendkim-Mode':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'Mode sv',
    match   => '^Mode',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-Canonicalization':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'Canonicalization relaxed/simple',
    match   => '^#?Canonicalization',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-KeyFile':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => '#KeyFile /etc/opendkim/keys/default.private',
    match   => '^KeyFile',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-KeyTable':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'KeyTable refile:/etc/opendkim/KeyTable',
    match   => '^#?KeyTable',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-SigningTable':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'SigningTable refile:/etc/opendkim/SigningTable',
    match   => '^#?SigningTable',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-ExternalIgnoreList':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'ExternalIgnoreList refile:/etc/opendkim/TrustedHosts',
    match   => '^#?ExternalIgnoreList',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-InternalHosts':
    ensure  => present,
    path    => '/etc/opendkim.conf',
    line    => 'InternalHosts refile:/etc/opendkim/TrustedHosts',
    match   => '^#?InternalHosts',
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-KeyTable-content':
    ensure  => present,
    path    => '/etc/opendkim/KeyTable',
    line    => "default._domainkey.${domain_name} ${domain_name}:default:/etc/opendkim/keys/default.private",
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-SigningTable-content':
    ensure  => present,
    path    => '/etc/opendkim/SigningTable',
    line    => "*@${domain_name} default._domainkey.${domain_name}",
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  file_line { 'opendkim-TrustedHosts':
    ensure  => present,
    path    => '/etc/opendkim/TrustedHosts',
    line    => $cidr,
    notify  => Service['opendkim'],
    require => Package['opendkim'],
  }

  postfix::config { 'smtpd_milters':
    ensure => present,
    value  => 'inet:127.0.0.1:8891',
  }

  postfix::config { 'non_smtpd_milters':
    ensure => present,
    value  => '$smtpd_milters',
  }

  postfix::config { 'milter_default_action':
    ensure => present,
    value  => 'accept',
  }

}
