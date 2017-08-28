# == Class: role_storage-analytics
#
# Manifest for installing additional support software for gathering storage-analytics
# 
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class role_storage-analytics (
  $scriptdir            = '/opt/storageanalytics',
  $storage_type         = 'fileshare',
  $data_status          = 'production',
  $data_name            = 'homedir',
  $storage_location     = 'primary-cluster-001',
  $cronminute           = '0',
  $cronminuterandom     = '59',
  $cronhour             = '0',
  $cronhourrandom       = '4',
  $cronweekday          = '0',
  $datadir              = '/data',
  $output_file          = '/var/log/storage-analytics.json',
  $pythonscriptsrepo    = 'https://github.com/naturalis/storage-analytics',
  $pip_packages         = ['scandir','ldap3'],

# variables used by config.ini for python scripts
  $admin_endpoint_ip    = '127.0.0.1',
  $os_username          = 'admin',
  $os_password          = 'secret',
  $os_project_name      = 'admin',
  $ad_user              = 'your_ad_user',
  $ad_password          = 'your_ad_password',
  $ad_domain            = 'SHORT_DOMAIN_NAME',
  $account_mail_to      = 'info@info.com',
  $ad_host              = '127.0.0.1',
  $ks_ad_group_sync_id  = 'ae41c863c3474201957e330885deda5e',
 )
{

  case $storage_type {
    'fileshare': {
      $script         = 'storage.fileshare.samba'
      $packages       = ['acl','git','smbclient']
    }
    'burp-backup-folder': {
      $script         = 'storage.backup.burp'
      $packages       = ['git']
    }
    'blockstorage-cinder': {
      $scripttemplate = 'storage.block.cinder'
      $packages       = ['git']
    }
  }

# create logrotate
  file { '/etc/logrotate.d/storage-analytics':
    ensure  => present,
    mode    => '0644',
    content => template('role_storage-analytics/logrotate.erb'),
  }

  if $packages {
    package {$packages:
      ensure      => installed
    }
  }

  file { $scriptdir:
    ensure        => 'directory',
  }

  file {['/etc/facter','/etc/facter/facts.d/']:
    ensure => directory,
  } ->
  file {'/etc/facter/facts.d/analytics_logs.yaml':
    ensure  => present,
    content => template('role_storage-analytics/analytics_logs_fact.erb'),
    mode    => '0775',
  }

  exec { "cleanup":
    path         => '/usr/bin:/usr/sbin:/bin',
    command      => "rm -rf ${scriptdir}/output ${scriptdir}/virtualenv ${scriptdir}/config.ini ${scriptdir}/gatherstats.sh",
    onlyif       => "test -e ${scriptdir}/output"
  }

  vcsrepo { "${scriptdir}/scripts":
    ensure        => latest,
    provider      => git,
    source        => $pythonscriptsrepo,
    require       => [File[$scriptdir],Package['git']],
  }

  file {"${scriptdir}/scripts/config.ini":
    ensure        => 'file',
    mode          => '0600',
    content       => template('role_storage-analytics/config.ini.erb'),
    require       => [File[$scriptdir],Vcsrepo["${scriptdir}/scripts"]]
  }

  if ($storage_type != 'burp-backup-folder'){
    cron { 'gatherstats':
      command       => "cd ${scriptdir}/scripts && /usr/bin/python -m ${script}",
      user          => 'root',
      minute        => $cronminute+fqdn_rand($cronminuterandom),
      hour          => $cronhour+fqdn_rand($cronhourrandom),
      weekday       => $cronweekday,
      require       => File["${scriptdir}/scripts/config.ini"]
    }
  }

  class { 'python' :
    version     => 'system',
    pip         => 'present',
    dev         => 'present',
    virtualenv  => 'present'
  }

  python::pip { $pip_packages :
    ensure        => 'present',
   }



}
