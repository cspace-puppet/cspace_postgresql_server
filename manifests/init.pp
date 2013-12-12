# == Class: postgresql_server
#
# Full description of class postgresql_server here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { postgresql_server:
#  servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#

include cspace_environment::execpaths
include cspace_environment::osbits
include cspace_environment::osfamily
include cspace_environment::tempdir

class cspace_postgresql_server ( $postgresql_version = '9.2.5' ) {
  
  # ---------------------------------------------------------
  # Obtain platform-specific values
  # ---------------------------------------------------------

  $system_temp_dir           = $cspace_environment::tempdir::system_temp_directory
  $os_family                 = $cspace_environment::osfamily::os_family
    
  case $os_family {
    RedHat, Debian: {
      $exec_paths = $cspace_environment::execpaths::linux_default_exec_paths
      $os_bits = $cspace_environment::osbits::os_bits
    }
    # OS X
    darwin: {
      $exec_paths = $cspace_environment::execpaths::osx_default_exec_paths
    }
    # Microsoft Windows
    windows: {
    }
    default: {
    }
  }

  # ---------------------------------------------------------
  # Download PostgreSQL
  # (EnterpriseDB installer)
  # ---------------------------------------------------------
  
  $postgresql_version_long   = "${postgresql_version}-1"
  $distribution_filename     = "postgresql-${postgresql_version_long}"
  $linux_64bit_extension     = 'linux-x64.run'
  $linux_32bit_extension     = 'linux.run'
  $osx_extension             = 'osx.dmg'
  $postgresql_repository_dir = 'http://get.enterprisedb.com/postgresql'
  
  case $os_family {
    RedHat, Debian: {
      if $os_bits == '64-bit' {
        $linux_extension = $linux_64bit_extension
      } elsif $os_bits == '32-bit' {
        $linux_extension = $linux_32bit_extension    
      } else {
        fail( 'Unknown hardware model when attempting to identify OS memory address size' )
      }
      $installer_filename   = "${distribution_filename}-${linux_extension}"
      exec { 'Download PostgreSQL installer':
        command => "wget ${postgresql_repository_dir}/${filename}",
        cwd     => $system_temp_dir,
        creates => "${system_temp_dir}/${installer_filename}",
        path    => $exec_paths,
      }
    }
    # OS X
    darwin: {
      $installer_filename   = "${distribution_filename}-${osx_extension}"
      # exec { 'Download PostgreSQL installer':
      #   command => "wget ${postgresql_repository_dir}/${filename}",
      #   cwd     => $system_temp_dir,
      #   creates => "${system_temp_dir}/${installer_filename}",
      #   path    => $exec_paths,
      # }
    }
    # Microsoft Windows
    windows: {
    }
    default: {
    }
  }
  
  
  # ---------------------------------------------------------
  # Install PostgreSQL
  # (EnterpriseDB installer, unattended mode)
  # ---------------------------------------------------------
  
  $superpw = "foobar-45690" # temporary; need to get this from environment
  
  case $os_family {
    RedHat, Debian: {
      exec { 'Perform unattended installation of PostgreSQL':
        command => "./${installer_filename} --mode unattended --superpassword ${superpw}",
        cwd     => $system_temp_dir,
        path    => $exec_paths,
        require => Exec[ 'Download PostgreSQL installer' ]
      }
    }
    # OS X
    darwin: {
      exec { 'Mount PostgreSQL installer disk image':
        command => "hdiutil attach ${installer_filename}",
        cwd     => $system_temp_dir,
        path    => $exec_paths,
        # require => Exec[ 'Download PostgreSQL installer' ]
      }
      $osx_volume_name        = "/Volumes/PostgreSQL ${postgresql_version_long}"
      $osx_app_dir_name       = "postgresql-${postgresql_version_long}-osx.app"
      $osx_app_installer_name = "${osx_app_dir_name}/Contents/MacOS/osx-intel"
      # Note: must enclose full path to installer within double quotes due to
      # space character in volume name
      exec { 'Perform unattended installation of PostgreSQL':
        command => "\"${osx_volume_name}/${osx_app_installer_name}\" --mode unattended --superpassword ${superpw}",
        path    => $exec_paths,
        # require => Exec[ 'Mount PostgreSQL installer disk image' ]
      }
      # exec { 'Unmount PostgreSQL installer disk image':
      #   command => "hdiutil detach ${devicename}",
      #   cwd     => $system_temp_dir,
      #   path    => $exec_paths,
      #   require => [
      #     Exec[ 'Open PostgreSQL installer disk image' ],
      #     Exec[ 'Perform unattended installation of PostgreSQL' ],
      #   ]
      # }      
    }
    # Microsoft Windows
    windows: {
    }
    default: {
    }
  }

  
  # (expands to /Volumes/PostgreSQL\ 9.2.5-1/postgresql-9.2.5-1-osx.app )
  
  
  # Commented-out fragments for possible use in this module:
  
  # ./ppasmeta-9.2.x.x-linux.run --mode unattended 
  #   --superpassword database_superuser_password 
  #   --webusername edb_user_name@email.com 
  #   --webpassword edb_user_password
    
  # package { 'postgresql':
  #   ensure  => present,
  #   name  => 'postgresql-9.1',
  # }
  
  # class { 'postgresql::server':
  #   ipv4acls           => [
  #                   'host all postgres samehost ident',
  #                   'host nuxeo nuxeo samehost md5',
  #                   'host nuxeo reader samehost md5',
  #                   'host cspace cspace samehost md5',
  #                 ],
  # }

  # This 'include file' ought to go somewhere PostgreSQL-relevant
  # and/or we should edit PostgreSQL params directly

  $includefile = '/tmp/postgresql_include.conf'

  # file { $includefile:
  #   content => 'max_connections = 64',
  #   notify  => Class['postgresql::server::service'],
  # }
  # ->
  # postgresql::server::config_entry { 'include':
  #   value   => $includefile,
  # }

}


