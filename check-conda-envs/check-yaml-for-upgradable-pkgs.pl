#!/usr/bin/env perl
#
# Copyright 2023, Peter Menzel 
#
# Usage:
# Specify one conda .yaml file as argument
#
# Use option --markdown for markdown formated lines with format:
# | icon | channel | package name | old version | new version |
# in case of error:
# | ❌ |||| line |
#
# Use option --html for outputting a HTML table.
#

use strict;
use warnings;
use File::Basename;

my $icon_ok = '✔️ ';
my $icon_warn = '⚠️ ';
my $icon_err = '❌';

my $dirname = dirname(__FILE__);
my $fname_map_changelog = $dirname . "/map_pkg2changelog.tsv";

if(!(@ARGV == 1 or @ARGV == 2 && $ARGV[0] =~ "--markdown|--html")) {
	die "Usage:\n  $0 [--markdown|--html] conda-environment.yaml\n";
}

my $markdown = $ARGV[0] eq "--markdown" ? 1 : 0;
my $html = $ARGV[0] eq "--html" ? 1 : 0;
my $fname = $ARGV[-1];

my %map_changelog = ();
if(-r $fname_map_changelog) {
	if(open(my $fh_map_changelog, '<', $fname_map_changelog)) {
		while(<$fh_map_changelog>){
			my @F = split(/\s+/, $_);
			$map_changelog{$F[0]} = $F[1];
		}
		close($fh_map_changelog);
	}
}

my $exit_code = 0;

# check if conda is executable
my $status = system("conda info >/dev/null 2>&1");
if($status != 0) { die "Error: Cannot execute conda!"; }


# open environment yaml file

open(my $fh, '<', $fname) or die "Cannot open file \"$fname\"!\n";

# print table head for markdown and html
if($markdown) {
	print "|  | channel | package | current version | latest version |\n";
	print "| --- | --- | --- | --- | --- |\n";
}
elsif($html) {
	print "<table>\n";
	print "<tr><th></th><th>channel</th><th>package</th><th>current version</th><th>latest version</th></tr>\n";
}


my $read_entries = 0;
my $indent = 0;
my $skip = 0;
while(<$fh>){

	if(/dependencies:/) { $read_entries = 1; next;} # wait until reaching section "dependencies"
	next unless $read_entries;

	# ignore pip sections
	if(/^(\s+)- pip:/) { $skip = 1; $indent = length($1); next; }

	chomp;
	next if /^\s*#/; # skip comment lines
	next unless length; # skip empty lines
	#print "$_\n";
	# #decide if pip section ended
	if($skip and /^(\s+)-/) { if(length($1) == $indent) { $skip = 0; } else { next; } }

	my ($channel, $pkg, $ver, $search_string);
	if(/-\s+([0-9a-zA-Z\-_]+)::([0-9a-zA-Z\-_.]+)(=|==|~=)([0-9.\-_a-zA-Z]+)/) { # any appended "=build_id" will be ignored here
		$channel = $1;
		$pkg = $2;
		$ver = $4;
		$search_string = "$channel" . "::" . $pkg . ">" .$ver;
	}
	elsif(/-\s+([0-9a-zA-Z\-_.]+)(=|==|~=)([0-9.\-_a-zA-Z]+)/) { # any appended "=build_id" will be ignored here
		$pkg = $1;
		$ver = $3;
		$search_string = "$pkg>$ver";
	}
	else {
		if($markdown) {
			print "| ❌ | ` $_ ` ||||\n";
		}
		elsif($html) {
			print "<tr><td>❌</td><td colspan=\"4\"><code>$_</code></td></tr>\n";
		}
		else {
			print "❌ Wrong format in \"$_\"! Allowed format is \"  - [<channel>::]<pkg-name>=<version>\"\n";
		}
		$exit_code = 1;
		next;
	}

	my @result = `conda search -q '$search_string' 2>/dev/null`;
	#print STDERR "Search result for $search_string is:\n@result\n";

	# add links to release notes
	if(defined $map_changelog{$pkg}) {
		if($html) {
			$pkg = "<a href=\"" . $map_changelog{$pkg} . "\">$pkg</a>";
		}
		elsif($markdown) {
			$pkg = "[$pkg]($map_changelog{$pkg})";
		}
	}

	my $c = defined $channel ? $channel : "";
	if(grep(/No match found for/, @result)) {
		if($markdown) {
			print "| $icon_ok | $c | $pkg | $ver | $ver |\n";
		}
		elsif($html) {
			print "<tr><td>$icon_ok</td><td>$c</td><td>$pkg</td><td>$ver</td><td>$ver</td></tr>\n";
		}
		else {
			print "$icon_ok Package " . ($channel ? ($channel . "::") : "") . "$pkg $ver is the most recent available version\n";
		}
	}
	else {
		# assume highest version is in last line
		my @F = split(/\s+/, $result[-1]);
		if($markdown) {
			print "| $icon_warn | $c | $pkg | $ver | $F[1] |\n";
		}
		elsif($html) {
			print "<tr><td>$icon_warn</td><td>$c</td><td>$pkg</td><td>$ver</td><td>$F[1]</td></tr>\n";
		}
		else {
			print "$icon_warn Package " . (defined $channel ? ($channel . "::") : "") . "$pkg $ver: A newer version $F[1] is available\n";
		}
	}

}

close($fh);

if($html) {
	print "</table>\n";
}

exit($exit_code)

