class profile::mail::sender(
  String $relayhost_ip,
  String $origin,
) {
  class { 'postfix':
    inet_protocols => 'ipv4',
    relayhost      => $relayhost_ip,
    myorigin       => $origin,
    satellite      => true,
    manage_mailx   => false,
  }

  postfix::config { 'authorized_submit_users':
    ensure => present,
    value  => 'root, slurm',
  }
}

class profile::mail::relayhost(
  String $origin,
) {

  $cidr = profile::getcidr()
  $interface = split($::interfaces, ',')[0]
  $ipaddress = $::networking['interfaces'][$interface]['ip']

  class { 'postfix':
    inet_interfaces => "127.0.0.1, ${ipaddress}",
    inet_protocols  => 'ipv4',
    mynetworks      => "127.0.0.0/8, ${cidr}",
    myorigin        => $origin,
    mta             => true,
    relayhost       => 'direct',
    smtp_listen     => 'all',
    manage_mailx    => false,
  }

  postfix::config { 'authorized_submit_users':
    ensure => present,
    value  => 'root, slurm',
  }
}
