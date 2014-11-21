#!/usr/bin/perl
use strict;
#use warnings;
#use diagnostics;
use POSIX qw/strftime/;;
use Sys::Hostname;

### For issues with this script, contact ice4o@hotmail.com

### HELP
my $f = shift;		# we will evaluate the parameter to ensure it is the configuration file (.cfg)
if ($f !~ /.+\.cfg$/) {
	print "Incorrect configuration file name provided. It should be in format <configfile>.cfg.\n";
	exit;
}

my $prog_name = "./err_srch.pl";		# used only for the HELP
my $prog_version = "1.7.1";				# used only for the HELP

if (!$f) {
	&_err_help("usage");
	exit;
}
if (lc($f) eq "help") {
	&_err_help("usage");
	exit;
}
if (lc($f) eq "version") {
	&_err_help("version");
	exit;
}

############
### LOAD CONFIGURATION PARAMETERS
my %res = &loadtextconfig($f);

my $prg_run = $res{'enabled'} if defined $res{'enabled'};
if ($prg_run == 0) {
	print "Program execution is disabled from configuration file.\n";
	exit;
}

my $prg_notify = $res{'notify'} if defined $res{'notify'};
if (!$prg_notify) {
	print &_err_msg('notify');
	exit;
}

my $file = $res{'examine_log'} if defined $res{'examine_log'};
if (!$file) {
	print &_err_msg('examine_log');
	exit;
}

my $email = $res{'email'} if defined $res{'email'};
if (!$email) {
	print &_err_msg('email');
	exit;
}

my $database = $res{'database'} if defined $res{'database'};
if (!$database) {
	print &_err_msg('database');
	exit;
}
my $machine_hostname = hostname;
my $mailsubject = "$database @ $machine_hostname";

my $err_log_file = $res{'errorlog'} if defined $res{'errorlog'};
if (!$err_log_file) {
	print &_err_msg('errorlog');
	exit;
}

my $tail =	$res{'tail_bin'} if defined $res{'tail_bin'};
if (!$tail) {
	print &_err_msg('tail_bin');
	exit;
}

my $sendmail = $res{'sendmail_bin'} if defined $res{'sendmail_bin'};
if (!$sendmail) {
	print &_err_msg('sendmail_bin');
	exit;
}

my $seekfile = $res{'seekfile'} if defined $res{'seekfile'};
if (!$seekfile) {
	print &_err_msg('seekfile');
	exit;
}

my $seekfile_tmp = $res{'seekfile_tmp'} if defined $res{'seekfile_tmp'};
if (!$seekfile_tmp) {
	print &_err_msg('seekfile_tmp');
	exit;
}

my $includelist = $res{'include'} if defined $res{'include'};
if (!$includelist) {
	print &_err_msg('include');
	exit;
}
$includelist =~ s/\$/\Q\$\E/g;
my @include = split(/\,/, $includelist);

my $excludelist = $res{'exclude'} if defined $res{'exclude'};
if (!$excludelist) {
	print &_err_msg('exclude');
	exit;
}
#$excludelist =~ s/\$/\Q\$\E/g;
my @exclude = split(/\,/, $excludelist);

#foreach my $test (@exclude) {
#	print $test . "\n";
#}



#my @exclude;	# function to parse the hash
#exit;

my @err_arr;
my $logsize = -s $file;

####				
### THE CODE STARTS HERE

# no seek.file -> create seek.file and exit
if (-e $seekfile) {
	# FILE EXIST
	# Create tmp seek file
	open(TMPSEEK, ">$seekfile_tmp");
	printf TMPSEEK "$logsize";
	close(TMPSEEK);

	# FUNCTION TO CONTINUE THE LOGIC
	&_err_load();
	&_err_result2();
	
} else {
	print "File does not exist!\n";
	print "Creating it.\n";

	open(SEEK, ">$seekfile");
	printf SEEK "$logsize";
	close(SEEK);
	# SCRIPT ENDS HERE
}

# current file size > seek.file.tmp (new seek.file, rename it on script end)

# FUNCTION
# open & seek the file to seek.file position (OK)
# check for new error messages
# group err messages

sub _err_load
{
	# Get seekfile position
	if (!open(MYSEEK, $seekfile)) {
		print "Error, cannot open $seekfile\n";
		&_err_log("ERR: Cannot open $seekfile.");
		exit;
	}
	my $seekpos = <MYSEEK>;
	close(MYSEEK);
	
	## LOGFILE stands for database log file
	if (!open(DBLOG, $file)) {
		print "Error, cannot open $file\n";
		&_err_log("ERR: Cannot open logfile $file.");
		exit;
	}

	if (!seek(DBLOG, $seekpos, 1)) {
		print "Error, cannot seek to $seekpos on $file\n";
		&_err_log("ERR: Cannot seek to $seekpos on $file.");
		exit;
	} else {
		while (<DBLOG>) {
			chomp;
			&_err_check($_);
		}
		close(DBLOG);
		# move tmp log file to original one
		if (!unlink($seekfile)) {
			print "Error, cannot delete $seekfile\n";		
			&_err_log("ERR: Cannot delete $seekfile.");
			exit;
		}
		if (!rename($seekfile_tmp, $seekfile)) {
			print "Error, cannot rename $seekfile_tmp to $seekfile.";
			&_err_log("ERR: Cannot rename $seekfile_tmp to $seekfile.");
			exit;
		}
	}
}

# THIS FUNCTION PARSES THE LAST SECTION FOR ERRORS
sub _err_check
{
	my $log = shift;
	foreach my $in (@include) {
		$in =~ s/\"//g;	# escape quotes "
		if ($log =~ /$in/) {
		
			my $exception = 0;
			foreach my $ex (@exclude) {
				$ex =~ s/\"//g;	# escape quotes "
				if ($log =~ /$ex/) { $exception = 1; }
			}
			## add search for timestamp and print the whole block
			#### NEW STUFF
			if ($exception == 0) { push(@err_arr, $log); }
		}
	}
}

# Parser of the result
# submitted by _err_check()
#### UNUSED FUNCTION
sub _err_result
{
	if(@err_arr) {
		## add timestamp
		#unshift(@err_arr, strftime('%d-%b-%Y %H:%M:%S',localtime));
		
		# extract only unique values
		my %hash = map { $_ => 1 } @err_arr;
		my @unique = keys %hash;
		my $res;
		foreach(@unique) {
			### EMAIL THE RESULT OF $_
			$res .= "$_\n"; 
			#print "$_\n";
		}
		&_err_mail($res);
	} else {
		# No error messages
		&_err_log("MSG: No error messages.");
	}
}

# Count unique results
# requires array err_arr, comes from err_check
sub _err_result2
{
	if (@err_arr) {
		my $hash_unique_res = {};
		my $res;
		
		foreach (@err_arr) {
			$hash_unique_res->{$_}++;
		}
		foreach (keys %{$hash_unique_res}) {
			$res .= "$hash_unique_res->{$_} times: $_\n";
		}
		&_err_mail($res);		
	} else {
		# No error messages
		&_err_log("MSG: No error messages.");
	}
}

# Email all error messages for the last minute
# submitted by _err_result()
sub _err_mail
{
	my $message = shift;
	# add timestamp in the beginning of the message
	$message = strftime('%d-%b-%Y %H:%M:%S',localtime) . "\n\n" . $message;
	$message = qq(From: "Prod log watcher"\nTo: $email\nSubject: $mailsubject\n) . $message;
	if ($prg_notify eq "yes") {
		open(MAIL, "| $sendmail -t") or &_err_log("ERR: Cannot send email due to the following error: $_");
		print MAIL $message;
		&_err_log("MSG: Email message sent to $email.");
		close(MAIL);
	} else {
		print "$message\n";
		exit;
	}
}

## Program logger
sub _err_log
{
	my $err_log_msg = shift;
	# add timestamp to the message
	$err_log_msg = strftime('%d-%b-%Y %H:%M:%S',localtime) . " " . $err_log_msg . "\n";
	
	if (-e $err_log_file) {
		if (-w $err_log_file) {
			# File exist so we just append
			open(LOG, ">>$err_log_file");
			printf LOG "$err_log_msg";
			close(LOG);
		} else {
			# Log file not writable by the current user
			print "Error, cannot append to file: $err_log_file\n";
			exit;
		}
	} else {
		# File does not exist so we create it for the first time
		open(LOG, ">$err_log_file") or die("Error, cannot create $err_log_file\n");
		printf LOG "$err_log_msg";
		close(LOG);
	}
}

## HELP FUNCTION
sub _err_help
{
	## Depends on email, so we define an email in case of email not being set.
	my $msg = shift;
	if (lc($msg) eq "usage") {
		print "Usage:\n";
		print "perl $prog_name\t\t\t\t-\> prints this help\n";
		print "perl $prog_name help\t\t\t\t-\> prints this help\n";
		print "perl $prog_name version\t\t\t-\> prints program version\n";
		print "perl $prog_name \<CONFIGURATION_FILE\>\t\t-\> executes the program with parameters loaded from the configuration file\n";
		print "-----\n";
		print "NOTE: parameters should be inserted without \<\> symbols!\n";
	}
	if (lc($msg) eq "version") {
		print "Credits:\n";
		print "Log checker \(err_srch.pl\)\n";
		print "Version: $prog_version\n";
		print "Please send any requests, errors or comments, to ice4o\@hotmail.com\n";
	}
}

## LOAD CONFIG FILE
sub loadtextconfig
{
	my $f   = shift;
	my %href;
	my ($i,$j)              = (0,0);

	open(W,$f) || die  "ERROR: Could not open configuration file: $f!\n";
	while (<W>) {
		next if /^#/;									# ignore commented lines
		$_ =~ s/\r|\n//g;								# remove ending carriage return and/or newline
		s/\s+//g;										# remove whitespace
		s/;.*//g;
		next unless length;							# skip blank lines
		
		chomp($i);
		($i,$j) = split(/=/,$_,2);					# $j holds rest of line
		
		$j = "" unless (defined $j);
		$j =~ s/^\s+//;								# remove leading whitespace
		$href{$i} = $j;
	}
	close(W);
	return %href;
	#print Dumper($href);
	#print "loadtextconfig $f: <PRE>\n" . Dumper($href) . "</PRE>\n";
}

sub _err_msg
{
		# usage &_err_msg('examine_log')
		# print error message on stdout
		my $param = shift;
		my $msg = "Parameter '$param' is not defined or is empty! Please check the configuration file.\n";
		return $msg;
}
