#!/usr/bin/perl -w

=head1 NAME

Alien::Package::Tgz - an object that represents a tgz package

=cut

package Alien::Package::Tgz;
use strict;
use Alien::Package; # perlbug
use base qw(Alien::Package);

=head1 DESCRIPTION

This is an object class that represents a tgz package, as used in Slackware. 
It is derived from Alien::Package.

=head1 CLASS DATA

=over 4

=item scripttrans

Translation table between canoical script names and the names used in
tgz's.

=cut

use constant 
	scriptrans => {
		postinst => 'doinst.sh',
		postrm => 'delete.sh',
		prerm => 'predelete.sh',
		preinst => 'predoinst.sh',
	};

=back

=head1 FIELDS

=over 4

=head1 METHODS

=over 4

=item checkfile

Detect tgz files by their extention.

=cut

sub checkfile {
        my $this=shift;
        my $file=shift;

        return $file =~ m/.*\.(?:tgz|tar\.(?:gz|Z|z)|taz)$/;
}

=item install

Install a tgz with installpkg. Pass in the filename of the tgz to install.

installpkg (a slackware program) is used because I'm not sanguine about
just untarring a tgz file. It might trash a system.

=cut

sub install {
	my $this=shift;
	my $tgz=shift;

	if (-x "/sbin/installpkg") {
		system("/sbin/installpkg $tgz") &&
			die "Unable to install: $!";
	}
	else {
		die "Sorry, I cannot install the generated .tgz file because /sbin/installpkg is not present. You can use tar to install it yourself.\n"
	}
}

=item scan

Scan a tgz file for fields. Has to scan the filename for most of the
information, since there is little useful metadata in the file itself.

=cut

sub scan {
	my $this=shift;
	$this->SUPER::scan(@_);
	my $file=$this->filename;

	# Get basename of the filename.
	my ($basename)=('/'.$file)=~m#^/?.*/(.*?)$#;

	# Strip out any tar extentions.
	$basename=~s/\.(tgz|tar\.(gz|Z))$//;

	if ($basename=~m/(.*)-(.*)/ ne undef) {
		$this->name($1);
		$this->version($2);
	}
	else {
		$this->name($basename);
		$this->version(1);
	}

	$this->arch('all');

	$this->summary("Converted Slackware tgz package");
	$this->description($this->summary);
	$this->copyright('unknown');
	$this->release(1);
	$this->distribution("Slackware");
	$this->origformat('tgz');

	# Now figure out the conffiles. Assume anything in etc/ is a
	# conffile.
	my @conffiles;
	open (FILELIST,"tar zvtf $file | grep etc/ |") ||
		die "getting filelist: $!";
	while (<FILELIST>) {
		# Make sure it's a normal file. This is looking at the
		# permissions, and making sure the first character is '-'.
		# Ie: -rw-r--r--
		if (m:^-:) {
			# Strip it down to the filename.
			m/^(.*) (.*)$/;
			push @conffiles, "/$2";
		}
	}
	$this->conffiles(\@conffiles);

	# Now get the whole filelist. We have to add leading /'s to the
	# filenames. We have to ignore all files under /install/
	my @filelist;
	open (FILELIST, "tar ztf $file |") ||
		die "getting filelist: $!";
	while (<FILELIST>) {
		unless (m:^install/:) {
			push @filelist, "/$_";
		}
	}
	$this->filelist(\@filelist);

	# Now get the scripts.
	foreach my $script (keys %{scripttrans()}) {
		$this->$script(`tar Oxzf $file 	install/${scripttrans()}{$script} 2>/dev/null`);
	}

	return 1;
}

=item unpack

Unpack tgz.

=cut

sub unpack {
	my $this=shift;
	$this->SUPER::unpack(@_);
	my $file=$this->filename;

	system("cat $file | (cd ".$this->unpacked_tree."; tar zxpf -)") &&
		die "Unpacking of `$file' failed: $!";
	# Delete the install directory that has slackware info in it.
	system("cd ".$this->unpacked_tree."rm -rf ./install");

	return 1;
}

=item prep

Adds a populated install directory to the build tree.

=cut

sub prep {
	my $this=shift;
	my $dir=$this->unpacked_tree || die "The package must be unpacked first!";

	my $install_made=0;
	foreach my $script (keys %{scriptrans()}) {
		my $data=$this->$script();
		next if ! defined $data || $data =~ m/^\s*$/;
		if (!$install_made) {
			mkdir $this->unpacked_tree."/install", 0755;
			$install_made=1;
		}
		open (OUT, ">".$this->unpacked_tree."/install/$script") ||
			die $this->unpacked_tree."/install/$script: $!";
		print OUT $data;
		close OUT;
		chmod 0755, $this->unpacked_tree."/install/$script";
	}
}

=item build

Build a tgz.

=cut

sub build {
	my $this=shift;
	my $tgz=$this->name."-".$this->version.".tgz";

	system("cd ".$this->unpacked_tree."; tar czf ../$tgz");

	return $tgz;
}

=head1 AUTHOR

Joey Hess <joey@kitenet.net>

=cut

1
