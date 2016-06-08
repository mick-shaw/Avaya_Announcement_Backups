#! /usr/bin/perl

##########################################################
# 	     Aura Announcement Backup Application
#
# Author:  Mick Shaw
# Company: Potomac Integration and Consulting
# Date:    05/29/2016
#
#
# A utlity script that enables filexfer on each VAL board
# and Media Gateway internal announcement module and 
# then transfers the announcement files to a locally defined
# directory. Finally, it disables filexfer within CM.
#
# "$pbx" variable defines the CM instance. The connection
# details of each instance must defined in the OSSI
# Module (cli_ossi.pm).
#
# Note: CM instances have to be defined in the cli_ossi module
# before they can be referenced as $pbx variable value.
#
###########################################################


use strict;
use warnings;
use feature qw(say);
use autodie;
use Time::localtime;
use Net::SFTP::Foreign;
use Net::FTP;	
use File::Basename;
use File::Path qw/make_path/;

require "/opt/Avaya-Utility-Script/cli_ossi.pm";
import cli_ossi;


my $enable_filexfer_login = 			'720fff00';
my $enable_filexfer_passwd = 			'7210ff00';
my $enable_filexfer_reenterpasswd = 		'7214ff00';
my $enable_filexfer_secure = 			'7211ff00';
my $enable_filexfer_board = 			'7212ff00';
my $list_ip_interface_val_slot =		'7002ff00';
my $list_ip_interface_val_ip =			'7213ff00';
my $list_media_gateways_ip =			'6c03ff00';
my $list_media_gateways_number =		'6c00ff00';


my $sftp;
my $VAL_DUMP;
my $MG_DUMP;
my $pbx;
my $node;
my $debug;
my $val_dir;
my $valboard;
my $valIP;
my $mg_Annc;
my $mg_IP;
my $pattern;
my $pbxcounter = 0;
my $file;
my $localfile;
my $base_dir = "/home/avayabkup/AnnouncementBackups/";


#=============================================================
sub timestamp {
#=============================================================

  my $t = localtime;
  return sprintf( "%04d-%02d-%02d_%02d-%02d-%02d",
                  $t->year + 1900, $t->mon + 1, $t->mday,
                  $t->hour, $t->min, $t->sec );

                 }

#=============================================================
sub getVALBoards {
#=============================================================

	
	my($node) = @_;
	my @VALBoards;
	$node->pbx_command("list ip-interface val");
	if ( $node->last_command_succeeded() ) {
		@VALBoards= $node->get_ossi_objects();
	}
	return @VALBoards;

}

#=============================================================
sub getMediaGateways {
#=============================================================

	
	my($node) = @_;
	my @MediaGateways;
	$node->pbx_command("list media");
	if ( $node->last_command_succeeded() ) {
		@MediaGateways= $node->get_ossi_objects();
	}
	return @MediaGateways;

}

#=============================================================
sub enableSFTP{
#=============================================================	

#enable_filexfer_login
#Login Value must be more than 3 and less than 6 characters

#enable_filexfer_passwd and enable_filexfer_reenterpasswd
#Password must be 7 to 12 character alpha-numeric password containing at least
#one digit and one character

# enable_filexfer_secure (Default value is SFTP)
# y for SFTP and n for FTP

# enable_filexfer_board
# Enter sourceboard location :[cabinet(1-64)];carrier(A-E);slot(slot#)

my ($node, $slot) = @_;
my %field_params = ( $enable_filexfer_login => 'mick', $enable_filexfer_passwd => 'Passw0rd', $enable_filexfer_reenterpasswd => 'Passw0rd', $enable_filexfer_board => $slot );
my $command = "enable filexfer";
$node->pbx_command( $command, %field_params );
if ($node->last_command_succeeded())
{
return(0);
}
else {
		print "Error: ". $node->get_last_error_message ."\n";
		return(1);
	}
}

#=============================================================
sub enableFTP{
#=============================================================	

#enable_filexfer_login
#Login Value must be more than 3 and less than 6 characters

#enable_filexfer_passwd and enable_filexfer_reenterpasswd
#Password must be 7 to 12 character alpha-numeric password containing at least
#one digit and one character

# enable_filexfer_secure
# "n" for FTP

# enable_filexfer_board
# Enter sourceboard location :[cabinet(1-64)];carrier(A-E);slot(slot#)

my ($node, $slot) = @_;
my %field_params = ( $enable_filexfer_secure => 'n', $enable_filexfer_login => 'mick', $enable_filexfer_passwd => 'Passw0rd', $enable_filexfer_reenterpasswd => 'Passw0rd', $enable_filexfer_board => $slot );
my $command = "enable filexfer";
$node->pbx_command( $command, %field_params );
if ($node->last_command_succeeded())
{
return(0);
}
else {
		print "Error: ". $node->get_last_error_message ."\n";
		return(1);
	}
}
#=============================================================
sub disablefilexfer {
#=============================================================

my ($node, $slot) = @_;
my $command = "disable filexfer board $slot";
$node->pbx_command( $command );
if ($node->last_command_succeeded())
{
return(0);
}
else {
		print "Error: ". $node->get_last_error_message ."\n";
		return(1);
	}
}

# This while loop needs to be adjusted based on the number of
# PBXs you have.  The $pbx values must first be defined in the
# cli_ossi.pm module.

while ($pbxcounter < 5) {
	if ($pbxcounter == 0){
		$pbx = 'CM1';
	}
	if ($pbxcounter == 1){
		$pbx = 'CM2';
	}
	if ($pbxcounter == 2){
		$pbx = 'CM3';
	}
	if ($pbxcounter == 3){
		$pbx = 'CM4';
	}
	if ($pbxcounter == 4){
		$pbx = 'CM5';
	}



			$node = new cli_ossi($pbx, $debug);
			unless( $node && $node->status_connection() ) {
			die("ERROR: Login failed for ". $node->get_node_name() );
			}

			foreach $VAL_DUMP (getVALBoards($node))

			{
					$valboard = $VAL_DUMP->{$list_ip_interface_val_slot};
					$valIP = $VAL_DUMP->{$list_ip_interface_val_ip},
					$val_dir = $base_dir . $pbx . "/" . $valboard . "/" . timestamp();
					
					#Need to make sure filexfer isn't already enabled.
					disablefilexfer($node,$valboard);

					enableSFTP($node,$valboard);

					use constant {
					    
					    REMOTE_DIR      	=> "/annc/",
					    LOCAL_DIR       	=> $val_dir,
						USER_NAME       => "mick",
						PASSWORD        => "Passw0rd",
						DEBUG           => "0",	
					                       };

					 
					$sftp = Net::SFTP::Foreign->new (
					                            $valIP,
					                            timeout         => 240,
					                            user            => USER_NAME,
					                            password        => PASSWORD,
					                            more 	    => [-o => 'StrictHostKeyChecking no'],
					                            autodie         => 1,
					                            
					                                           );

					# The block_size option significantly slows the transfer.
					# However, could not successfully pull the announcement files without
					# limiting the size to 512KB.
					$sftp->rget( 
								"/annc/", 
								$val_dir,block_size => 512); 

					say "\nAnnouncements backed up successfully for $pbx VAL Board $valboard";

					$sftp->disconnect;

					#Don't want to leave filexfer enabled.
					disablefilexfer($node,$valboard);

			}

			foreach $MG_DUMP (getMediaGateways($node))

			{
					$mg_Annc = $MG_DUMP->{$list_media_gateways_number};
					$mg_Annc = "$mg_Annc"."v9";
					$mg_IP = $MG_DUMP->{$list_media_gateways_ip};

					disablefilexfer($node,$mg_Annc);
					enableFTP($node,$mg_Annc);
					$val_dir = $base_dir . $pbx . "/" . $mg_Annc . "/" . timestamp();
					
					if (-e $val_dir)
					{
						print "Directory already exists"
					}
					else
					{
						make_path($val_dir);
					}

					# Maybe one day Avaya will provide SFTP access to the 
					# media gateway announcements.  Until then, we'll have to
					# deal with FTP.  Ugh.

					my $ftp = Net::FTP->new("$mg_IP", Debug => 0)
					             or die "Cannot connect to $mg_IP: $@";
					$ftp->login("mick","Passw0rd")
					             or die "Cannot login ", $ftp->message;
					 $ftp->cwd("/annc")
					             or die "Cannot change working directory ", $ftp->message;
					foreach my $file ($ftp->ls($pattern)) {
					$localfile=$val_dir . "/" . $file;
					$ftp->get($file,$localfile) or warn $ftp->message;
					
					} 

					say "\nAnnouncements backed up successfully for $pbx MG Module $mg_Annc";

					disablefilexfer($node,$mg_Annc);

			}
					
					$node->do_logoff();
					$pbxcounter = $pbxcounter + 1;
}





