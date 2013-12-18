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

include cspace_environment::env
include cspace_environment::execpaths
include cspace_environment::osbits
include cspace_environment::osfamily
include cspace_environment::tempdir
include postgresql::client
include postgresql::globals
include postgresql::server
include stdlib # for 'join()'

class cspace_postgresql_server ( $postgresql_version = '9.2.5', $locale = 'en_US.UTF-8' ) {

  # ---------------------------------------------------------
  # Validate parameters
  # ---------------------------------------------------------

  # TODO: Can further tighten these regexes as needed
  
  if (! locale =~ /^.*?\.UTF8$/) {
    fail( "Unrecognized locale ${locale}" )
  }

  if (! $postgresql_version =~ /^\d+\.\d+\.\d+$/) and (! $postgresql_version =~ /^\d+\.\d+$/) {
    fail( "Unrecognized PostgreSQL version ${postgresql_version}" )
  }
    
  # ---------------------------------------------------------
  # Obtain major version number
  # ---------------------------------------------------------

  if $postgresql_version =~ /^(\d+\.\d+)\.\d+$/ {
      $postgresql_major_version = $1
  } else {
      $postgresql_major_version = $postgresql_version
  }

  # ---------------------------------------------------------
  # Obtain database superuser name and password
  # ---------------------------------------------------------

  $superacct = $cspace_environment::env::cspace_env['DB_USER']
  $superpw   = $cspace_environment::env::cspace_env['DB_PASSWORD']

  # ---------------------------------------------------------
  # Obtain operating system family
  # ---------------------------------------------------------
  
  $os_family       = $cspace_environment::osfamily::os_family
  
  # ---------------------------------------------------------
  # Obtain platform-specific values
  # ---------------------------------------------------------

  $system_temp_dir = $cspace_environment::tempdir::system_temp_directory
    
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
  
  
  # ######################################################################
  # Diverge here, depending on platform (Linux v. non-Linux),
  # by selecting one of the two options below
  # ######################################################################
  
  
  # ######################################################################
  # Install and configure PostgreSQL using a Linux package manager,
  # via the 'puppetlabs-postgresql' Puppet module 
  # ######################################################################
  
  case $os_family {
    RedHat, Debian: {
      notice( 'Setting global values to be used by installer ...' )
      class { 'postgresql::globals':
        # Rather than specifying the PostgreSQL version on Linux distros,
        # use the per-platform package manager defaults wherever available. 
        # This will help ensure that the appropriate packages are available.
        encoding => 'UTF8',
        locale   => $locale,
      }
      notice( 'Ensuring that PostgreSQL server is present ...' )
      # By default, 'ensure => present', so instantiating the following
      # resource will install the PostgreSQL server.
      #
      # Note: Attempting to set host-based access via the 'ipv4acls' attribute
      # together with 'pg_hba_conf_defaults => false' resulted in an error due
      # to missing fragment files when constructing pg_hba.conf. Thus, multiple
      # pg_hba_rule types have been used to configure that access, below.
      class { 'postgresql::server':
        # Disables the default set of host-based authentication settings,
        # since we're setting CollectionSpace-relevant access rules below.
        pg_hba_conf_defaults => false,
        postgres_password    => $superpw,
      }
      # By default, 'ensure => present', so instantiating the following
      # resource will install 'psql', the CLI PostgreSQL client.
      notice( 'Ensuring that \'psql\' PostgreSQL client is present ...' )
      class { 'postgresql::client':
      }
    }
    default: {
      # Do nothing
    }
  }
  
  # ---------------------------------------------------------
  # Configure host-based authentication settings
  # ---------------------------------------------------------

  # TODO: Add any additional access rules required, such as
  # rules required to support local or remote reporting, etc.
  
  case $os_family {
    RedHat, Debian: {
      notice( 'Ensuring additional PostgreSQL server host-based access rules, if any ...' )
      # Providing 'ident'-based access for the 'postgres' user appears to be required
      # by the puppetlabs-postgresql module for validating the database connection. (It may also
      # be required for setting the 'postgres' user's password, per postgresql::server::passwd.)
      postgresql::server::pg_hba_rule { 'TYPE  DATABASE  USER  ADDRESS  METHOD':
        order       => '20',
        description => 'Enable ident access over local (Unix domain socket) connections',
        type        => 'local',
        database    => 'all',
        user        => 'all',
        auth_method => 'ident',
      }
      postgresql::server::pg_hba_rule { 'superuser via IPv4':
        order       => '40',
        description => 'Superuser can access all databases via IPv4 from localhost',
        type        => 'host',
        database    => 'all',
        user        => $superacct,
        address     => 'samehost',
        auth_method => 'md5',
      }
      postgresql::server::pg_hba_rule { 'nuxeo user via IPv4':
        order       => '60',
        description => '\'nuxeo\' user can access all databases via IPv4 from localhost',
        type        => 'host',
        database    => 'all',
        user        => 'nuxeo',
        address     => 'samehost',
        auth_method => 'md5',
      }
      postgresql::server::pg_hba_rule { 'cspace user via IPv4':
        order       => '80',
        description => '\'cspace\' user can access \'cspace\' database via IPv4 from localhost',
        type        => 'host',
        database    => 'cspace',
        user        => 'cspace',
        address     => 'samehost',
        auth_method => 'md5',
      }
    }
    default: {
      # Do nothing
    }
  }
  
  # ---------------------------------------------------------
  # Configure main PostgreSQL settings
  # ---------------------------------------------------------

  # TODO: Change additional settings beyond those below, as
  # required for database tuning or other implementation-specific purposes.

  case $os_family {
    RedHat, Debian: {
      notice( 'Ensuring CollectionSpace-relevant PostgreSQL configuration settings ...' )
      postgresql::server::config_entry { 'max_connections':
        value   => 32, # Conservative default; could be changed to 64 
      }
    }
    default: {
      # Do nothing
    }
  }
    

  # ######################################################################
  # Install and configure PostgreSQL using the EnterpriseDB-packaged
  # installer for non-Linux platforms (OS X, Windows ...)
  # ######################################################################


  # ---------------------------------------------------------
  # Download PostgreSQL installer
  # ---------------------------------------------------------
  
  # Unlike platform-specific package installations, the
  # EnterpriseDB-packaged installer is cross-platform, and
  # generally keeps up with new PostgreSQL releases.
  # As well, many different past releases are available in
  # that organization's archives, if needed.
  
  # For unattended installation command line options, see:
  # http://www.enterprisedb.com/docs/en/9.2/instguide/
  # with the above URL followed by (to avoid line wrapping)
  # Postgres_Plus_Advanced_Server_Installation_Guide-16.htm
  # Postgres_Plus_Advanced_Server_Installation_Guide-18.htm
  
  $postgresql_version_long   = "${postgresql_version}-1"
  $distribution_filename     = "postgresql-${postgresql_version_long}"
  $linux_64bit_extension     = 'linux-x64.run'
  $linux_32bit_extension     = 'linux.run'
  $osx_extension             = 'osx.dmg'
  $postgresql_repository_dir = 'http://get.enterprisedb.com/postgresql'
  
  case $os_family {
    RedHat, Debian: {
      # if $os_bits == '64-bit' {
      #   $linux_extension = $linux_64bit_extension
      # } elsif $os_bits == '32-bit' {
      #   $linux_extension = $linux_32bit_extension    
      # } else {
      #   fail( 'Could not select Linux PostgreSQL installer: unknown value for OS virtual address space' )
      # }
      # $installer_filename   = "${distribution_filename}-${linux_extension}"
      # exec { 'Download PostgreSQL installer':
      #   command => "wget ${postgresql_repository_dir}/${installer_filename}",
      #   cwd     => $system_temp_dir,
      #   creates => "${system_temp_dir}/${installer_filename}",
      #   path    => $exec_paths,
      # }
      # exec { 'Set executable permissions on PostgreSQL installer':
      #   command => "chmod ug+x ${system_temp_dir}/${installer_filename}",
      #   path    => $exec_paths,
      # }
    }
    # OS X
    darwin: {
      notice( 'Downloading EnterpriseDB PostgreSQL installer ...' )
      $installer_filename   = "${distribution_filename}-${osx_extension}"
      exec { 'Download PostgreSQL installer':
        command   => "wget ${postgresql_repository_dir}/${installer_filename}",
        cwd       => $system_temp_dir,
        creates   => "${system_temp_dir}/${installer_filename}",
        path      => $exec_paths,
        logoutput => on_failure,
      }
    }
    # Microsoft Windows
    windows: {
    }
    default: {
    }
  }
  
  # ---------------------------------------------------------
  # Account for existing installation of PostgreSQL, if any
  # ---------------------------------------------------------
  
  # FIXME: 
  # We can't assume this manifest will always be run on a
  # system where PostgreSQL isn't already present. As a
  # result, we should first:
  #
  # * Check for the presence of PostgreSQL.
  # * Shut down PostgreSQL, if it's both present and running.
  # * Ensure that any existing data directory isn't 
  #   overwritten by a new installation.
  
  # ---------------------------------------------------------
  # Install PostgreSQL
  # (EnterpriseDB installer, unattended mode)
  # ---------------------------------------------------------
  
  # The EnterpriseDB installer:
  # Creates a system user to administer PostgreSQL.
  # Installs the PostgreSQL server:
  # * On OS X, in /Library/PostgreSQL/{version}
  # Installs 'psql', the CLI PostgreSQL client.
  # Configures the host-based authentication config file, pg_hba.conf,
  # with localhost-only settings (with the 9.2.5 installer under OS X):
  # --
  # TYPE  DATABASE        USER            ADDRESS                 METHOD
  # "local" is for Unix domain socket connections only
  # local   all           all                                     md5
  # IPv4 local connections:
  # host    all           all             127.0.0.1/32            md5
  # IPv6 local connections:
  # host    all           all             ::1/128                 md5
  # --
  # Configures the main config file, postgresql.conf, with mostly default
  # (commented-out) settings, save for local timezone, locale, etc.
  # Starts the PostgreSQL server.
  # Creates an administrative PostgreSQL user ("superuser").
  
  case $os_family {
    RedHat, Debian: {
      # $install_cmd = join(
      #   [
      #     "$system_temp_dir/${installer_filename}",
      #     " --mode unattended --locale ${locale}",
      #     " --superaccount ${superacct} --superpassword ${superpw}",
      #   ]
      # )
      # notice( 'Running the EnterpriseDB PostgreSQL installer ...' )
      # exec { 'Perform unattended installation of PostgreSQL':
      #   command => $install_cmd,
      #   path    => $exec_paths,
      #   require => [
      #     Exec[ 'Download PostgreSQL installer' ],
      #     Exec[ 'Set executable permissions on PostgreSQL installer' ],
      #   ]
      # }
    }
    # OS X
    darwin: {
      notice( 'Mounting EnterpriseDB PostgreSQL installer disk image ...' )
      # The OS X installer comes as a disk image (.dmg) file, which must first be
      # mounted as a volume before the installer it contains can be run.
      exec { 'Mount PostgreSQL installer disk image':
        command   => "hdiutil attach ${installer_filename}",
        cwd       => $system_temp_dir,
        # The existence of the following 'creates' attribute appeared to
        # prevent some mounts even when the volume wasn't mounted.
        # creates   => "${osx_volume_name}/${osx_app_installer_name}",
        path      => $exec_paths,
        logoutput => on_failure,
        require   => Exec[ 'Download PostgreSQL installer' ]
      }
      $osx_volume_name        = "/Volumes/PostgreSQL ${postgresql_version_long}"
      $osx_app_dir_name       = "postgresql-${postgresql_version_long}-osx.app"
      $osx_app_installer_name = "${osx_app_dir_name}/Contents/MacOS/osx-intel"
      # Note: must enclose the full path to the installer within double quotes
      # due to the presence of a space character in its volume name.
      $install_cmd = join(
        [
          "\"${osx_volume_name}/${osx_app_installer_name}\"",
          " --mode unattended --locale ${locale}",
          " --superaccount ${superacct} --superpassword ${superpw}",
        ]
      )
      # FIXME: This code works but is commented out for now.
      # Uncomment only for further testing, or after we've
      # put code in place to detect whether PostgreSQL is present.
      #
      # notice( 'Running the EnterpriseDB PostgreSQL installer ...' )
      # exec { 'Perform unattended installation of PostgreSQL':
      #   command => $install_cmd,
      #   path    => $exec_paths,
      #   require => Exec[ 'Mount PostgreSQL installer disk image' ]
      # }
      #
      # Unmounting of the installer volume, following installation,
      # is optional but recommended.
      #
      # TODO: This exec is incomplete. ${devicename} below might need
      # to be scraped from 'hdiutil info' as '/dev/disk{diskidentifier}'
      #
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
  
  # ---------------------------------------------------------
  # Configure host-based authentication settings
  # ---------------------------------------------------------

  # TODO: Tighten the default settings to restrict localhost
  # access to specific users and/or databases
  
  # TODO: Add any remote access needed for reporting, etc.

  # case $os_family {
  #   # OS X
  #   darwin: {
  #   }
  #   # Microsoft Windows
  #   windows: {
  #   }
  #   default: {
  #   }
  # }
  
  # ---------------------------------------------------------
  # Configure main PostgreSQL settings
  # ---------------------------------------------------------
  
  # TODO: Change any settings, as required, in the main
  # PostgreSQL configuration file
  #
  # This will include setting max_connections = 64 (or 32)
  
  # case $os_family {
  #   # OS X
  #   darwin: {
  #   }
  #   # Microsoft Windows
  #   windows: {
  #   }
  #   default: {
  #   }
  # }


  # ######################################################################
  # Converge back to a single path here
  # ######################################################################
  
  # ---------------------------------------------------------
  # Add datatype conversions
  # ---------------------------------------------------------
  
  $psql_cmd = 'psql -U postgres -d template1'
  
  # Function and associated datatype cast to convert integers to text
  $int_txt_func    = 'CREATE FUNCTION pg_catalog.text(integer) RETURNS text STRICT IMMUTABLE LANGUAGE SQL AS \'SELECT textin(int4out($1));\';'
  $int_txt_cast    = 'CREATE CAST (integer AS text) WITH FUNCTION pg_catalog.text(integer) AS IMPLICIT;'
  $int_txt_comment = 'COMMENT ON FUNCTION pg_catalog.text(integer) IS \'convert integer to text\';'
  
  # Function and associated datatype cast to convert 'bigints' to text
  $bigint_txt_func    = 'CREATE FUNCTION pg_catalog.text(bigint) RETURNS text STRICT IMMUTABLE LANGUAGE SQL AS \'SELECT textin(int8out($1));\';'
  $bigint_txt_cast    = 'CREATE CAST (bigint AS text) WITH FUNCTION pg_catalog.text(bigint) AS IMPLICIT;'
  $bigint_txt_comment = 'COMMENT ON FUNCTION pg_catalog.text(bigint) IS \'convert bigint to text\';'
  
  notice( 'Adding Nuxeo-required datatype conversions to the database ...' )
  case $os_family {
    RedHat, Debian: {
      exec { 'Add integer-to-text conversion function':
        command   => "${psql_cmd} -c \"${int_txt_func}\"",
        cwd       => $system_temp_dir,
        path      => $exec_paths,
        user      => $superacct,
        logoutput => on_failure,
        require   => [ 
          Class[ 'postgresql::server' ],
          Class[ 'postgresql::client' ],
        ]
      }
      exec { 'Add integer-to-text conversion cast':
        command   => "${psql_cmd} -c \"${int_txt_cast}\"",
        cwd       => $system_temp_dir,
        path      => $exec_paths,
        user      => $superacct,
        logoutput => on_failure,
        require   => [ 
          Class[ 'postgresql::server' ],
          Class[ 'postgresql::client' ],
        ]
      }
      exec { 'Add integer-to-text conversion comment':
        command   => "${psql_cmd} -c \"${int_txt_comment}\"",
        cwd       => $system_temp_dir,
        path      => $exec_paths,
        user      => $superacct,
        logoutput => on_failure,
        require   => [ 
          Class[ 'postgresql::server' ],
          Class[ 'postgresql::client' ],
        ]
      }
    }
    # OS X
    darwin: {
    }
    # Microsoft Windows
    windows: {
    }
    default: {
    }
  }

  
  
}



