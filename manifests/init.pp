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

}
