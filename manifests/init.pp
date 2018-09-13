#_gsuite == Class: role_infra_analytics
#
# Manifest for installing additional support software for gathering storage_analytics
# 
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class role_storage_analytics (
  $scriptdir            = '/opt/storageanalytics',
  $stat_type            = 'fileshare',
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
  $output_file_gsuite   = '/var/log/storage-analytics-gsuite.json',
  $pythonscriptsrepo    = 'https://github.com/naturalis/storage-analytics',

# variables used by config.ini for python scripts
  $admin_endpoint_ip            = '127.0.0.1',
  $os_username                  = 'admin',
  $os_password                  = 'secret',
  $os_project_name              = 'admin',
  $ad_user                      = 'your_ad_user',
  $ad_password                  = 'your_ad_password',
  $ad_domain                    = 'SHORT_DOMAIN_NAME',
  $account_mail_to              = 'info@info.com',
  $ad_host                      = '127.0.0.1',
  $ks_ad_group_sync_id          = 'ae41c863c3474201957e330885deda5e',
  $elastic_host                 = 'localhost',
  $elastic_port                 = '9200',
  $google_docs_credentials      = '',
  $google_reports_credentials   = '',
  $cmdb_key                     = '',
  $factsheet_key                = '',
  )
{

  case $role_storage_analytics::stat_type {
    'fileshare': {
      $script         = 'storage.fileshare.samba'
      $packages       = ['acl','git','smbclient']
      $pip_packages   = ['scandir','ldap3']
    }
    'burp-backup-folder': {
      $script         = 'storage.backup.burp'
      $packages       = ['git']
      $pip_packages   = ['scandir','ldap3']
    }
    'blockstorage-cinder': {
      $script         = 'storage.block.cinder'
      $packages       = ['git']
      $pip_packages   = ['scandir','ldap3']
    }
    'infra-stats': {
      $script         = 'infra_stats'
      $packages       = ['git']
      $pip_packages   = ['oauth2client', 'elasticsearch', 'google-api-python-client']
    }
  }

# create logrotate
  file { '/etc/logrotate.d/storage_analytics':
    ensure  => present,
    mode    => '0644',
    content => template('role_storage_analytics/logrotate.erb'),
  }

  if $packages {
    package {$packages:
      ensure      => installed
    }
  }

  file { $role_storage_analytics::scriptdir:
    ensure        => 'directory',
  }

  file {['/etc/facter','/etc/facter/facts.d/']:
    ensure => directory,
  } ->
  file {'/etc/facter/facts.d/analytics_logs.yaml':
    ensure  => present,
    content => template('role_storage_analytics/analytics_logs_fact.erb'),
    mode    => '0775',
  }

  exec { "cleanup":
    path         => '/usr/bin:/usr/sbin:/bin',
    command      => "rm -rf ${role_storage_analytics::scriptdir}/output ${role_storage_analytics::scriptdir}/virtualenv ${role_storage_analytics::scriptdir}/config.ini ${role_storage_analytics::scriptdir}/gatherstats.sh",
    onlyif       => "test -e ${role_storage_analytics::scriptdir}/output"
  }

  vcsrepo { "${role_storage_analytics::scriptdir}/scripts":
    ensure        => latest,
    provider      => git,
    source        => $role_storage_analytics::pythonscriptsrepo,
    require       => [File[$role_storage_analytics::scriptdir],Package['git']],
  }

  file {"${role_storage_analytics::scriptdir}/scripts/config.ini":
    ensure        => 'file',
    mode          => '0600',
    content       => template('role_storage_analytics/config.ini.erb'),
    require       => [File[$role_storage_analytics::scriptdir],Vcsrepo["${role_storage_analytics::scriptdir}/scripts"]]
  }

  if ($role_storage_analytics::stat_type == 'fileshare') or ($role_storage_analytics::stat_type == 'blockstorage-cinder'){
    cron { 'gatherstats':
      command       => "cd ${role_storage_analytics::scriptdir}/scripts && /usr/bin/python -m ${script}",
      user          => 'root',
      minute        => $role_storage_analytics::cronminute+fqdn_rand($role_storage_analytics::cronminuterandom),
      hour          => $role_storage_analytics::cronhour+fqdn_rand($role_storage_analytics::cronhourrandom),
      weekday       => $role_storage_analytics::cronweekday,
      require       => File["${role_storage_analytics::scriptdir}/scripts/config.ini"]
    }
  }

  if ($role_storage_analytics::stat_type == 'infra-stats'){
    cron { 'gsuitestats':
      command       => "cd ${role_storage_analytics::scriptdir}/scripts && /usr/bin/python -m storage.web.gsuite",
      user          => 'root',
      minute        => $role_storage_analytics::cronminute,
      hour          => $role_storage_analytics::cronhour,
      weekday       => $role_storage_analytics::cronweekday,
      require       => File["${role_storage_analytics::scriptdir}/scripts/config.ini"]
    }
    cron { 'infrastats':
      command       => "cd ${role_storage_analytics::scriptdir}/scripts && /usr/bin/python -m ${script}",
      user          => 'root',
      minute        => $role_storage_analytics::cronminute + 30,
      hour          => $role_storage_analytics::cronhour + 1,
      weekday       => $role_storage_analytics::cronweekday,
      require       => File["${role_storage_analytics::scriptdir}/scripts/config.ini"]
    }
    file {"${scriptdir}/scripts/google-docs-authentication.json":
      ensure        => 'file',
      mode          => '0600',
      content       => template('role_storage_analytics/google-docs-authentication.json.erb'),
      require       => [File[$scriptdir],Vcsrepo["${scriptdir}/scripts"]]
    }
    file {"${scriptdir}/scripts/google-reports-authentication.json":
      ensure        => 'file',
      mode          => '0600',
      content       => template('role_storage_analytics/google-reports-authentication.json.erb'),
      require       => [File[$scriptdir],Vcsrepo["${scriptdir}/scripts"]]
    }
    python::pip { 'gspread' :
      pkgname       => 'gspread',
      ensure        => '3.0.1'
    }
  }

  class { 'python' :
    version     => 'system',
    pip         => 'present',
    dev         => 'present',
    virtualenv  => 'present'
  }

  python::pip { $role_storage_analytics::pip_packages :
    ensure        => 'present',
  }

}
