use warnings;
use strict;
use Getopt::Std; 
use File::Find;

my %myopts = ();
my $title = "\n|    파 일 명                |\t라인수\t  문자수\n"."=" x 48 ."\n" ;

getopts("dh",\%myopts) or HELP_MESSAGE() ; 

defined($myopts{h}) and HELP_MESSAGE() ; 
	
my @flist = map { glob } @ARGV ;
if ( @flist == 0 ) { print "대상을 찾을수 없습니다.\n"; exit 1; }
if ( defined($myopts{d}) ) {
	find(\&delete_file , @flist) ;
}
else
{
	find(\&count_file, @flist) ;
}

sub count_file {
	local $/;
	return if -d $_;
	open (my $FF,$_) or  next ;

	my $ln = (<$FF> =~ tr/\n//) ;
	my $sz = -s $_ ;
	print $title ;
	$title = "";
	printf ("%-30s\t%6d\t%8d\n",$File::Find::name, $ln+1, $sz) ;
	close $FF;
}

sub delete_file {

	print " ** $_ **\n";
=begin comment
	foreach my $FNM (@flist)
	{
		next if -d $FNM;
		unlink $FNM or warn "삭제되지 않았습니다. $FNM: $!" ;
	}
=cut
}
sub HELP_MESSAGE{
  die <<'HEND';
  
Usage : $0 -d filelist
 -d : 지정파일 삭제
 
HEND
}