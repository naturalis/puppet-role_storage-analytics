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
      $scripttemplate = 'gatherfilesharestats.sh.erb'
      $packages       = ['acl']
    }
    'backup': {
      $scripttemplate = 'gatherbackupstats.sh.erb'
    }
  }

  if $packages {
    package {$packages:
      ensure      => installed
    }
  }

  file { $scriptdir:
    ensure        => 'directory',
  }

  file { "${scriptdir}/output":
    ensure        => 'directory',
    require       => File[$scriptdir],
  }


  file {"${scriptdir}/gatherstats.sh":
    ensure        => 'file',
    mode          => '0755',
    content       => template("role_storage-analytics/${scripttemplate}"),
    require       => File[$scriptdir]
  }

  cron { 'gatherstats':
    command       => "${scriptdir}/gatherstats.sh",
    user          => 'root',
    minute        => $cronminute+fqdn_rand($cronminuterandom),
    hour          => $cronhour+fqdn_rand($cronhourrandom),
    weekday       => $cronweekday,
    require       => File["${scriptdir}/gatherstats.sh"]
  }

  if ($data_status == 'dev'){

    file {"${scriptdir}/config.ini":
      ensure        => 'file',
      mode          => '0600',
      content       => template('role_storage-analytics/config.ini.erb'),
      require       => File[$scriptdir]
    }


    class { 'python' :
      version     => 'system',
      pip         => 'present',
      dev         => 'present',
      virtualenv  => 'present'
    }

    python::virtualenv { 'storageanalytics' :
      ensure       => present,
      version      => 'system',
      systempkgs   => true,
      venv_dir     => "${scriptdir}/virtualenv",
      owner        => 'root',
      group        => 'root',
      timeout      => 0,
      require      => File[$scriptdir]
    }
  
  }
}
