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
  $data_lifecycle_stage = 'production',
  $storage_location     = 'primary-cluster-001',
  $cronminute           = '0',
  $cronhour             = '0',
  $cronweekday          = '0',
  $datadir              = '/data',
 )
{

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
    content       => template('role_iontorrent/gatherstats.sh.erb'),
    require       => File[$scriptdir]
  }

  cron { 'gatherstats':
    command       => "${scriptdir}/gatherstats.sh",
    user          => 'root',
    minute        => $cronminute,
    hour          => $cronhour,
    weekday       => $cronweekday,
    require       => File["${scriptdir}/gatherstats.sh"]
  }

}
