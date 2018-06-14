use warnings;
use strict;
use File::Find;
use File::Basename;
#use File::Path qw(make_path );
use Getopt::Std; 
use IO::Handle;
use Dawin;

my %myopts = ();
my ($wfile,$exts);

getopts("hqo:e:",\%myopts);

if ( defined($myopts{h}) ) {
	&HELP_MESSAGE();
	exit;
}	

if ( defined($myopts{o}) ) {
	$wfile = $myopts{o} ;
}

if ( defined($myopts{e}) ) {
	$exts = $myopts{e} ;
	$exts =~ s/,/|/g ;
	print $exts,"\n" ;
}

my @dir = ('.')  ;
@dir = map { glob } @ARGV  if (@ARGV > 0) ;

print "검색 directory --> $dir[0]\n";

my $TOT_CNT = 0 ;

my ( $FHW,$ext ) ;
my	$Fn1 = \&inspect_table ;
STDOUT->autoflush() ;
if ( defined($wfile) ) {
  print "** 결과파일 --> $wfile \n";
  open($FHW,">",$wfile) || die "$wfile $! \n";
}  else {$FHW = *STDOUT;}
$FHW->autoflush() ;

if  ( defined($myopts{q}) ) {
	$Fn1 = \&inspect_query ;
	print $FHW " DIR \t 파일명 \t Query \n" ;
} else  {
	$Fn1 = \&inspect_table ;
	print $FHW " DIR \t 파일명 \t Table \n" ;
}

find($Fn1, @dir);

if ( defined($wfile) ) {
  close($FHW) ;
}

sub inspect_table {
	if ($exts) { return unless /($exts)$/ ; }
	return if ( -d || /\.(txt|log|exe|pdf|bak|tar|jar|jpg|png|ico|bmp|jpeg|xpm)?$/i || /\d{8,}/ ) ;
	return if (-s > 1024*1024*20);

  	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$TOT_CNT++;
	Dawin::PRINT_1($TOT_CNT,$_) ; 
	my $cdir = $File::Find::dir;
#	$cdir =~ s!^$dir/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	local $/;
  	my $ls=<$FF> ;
    close $FF ;
	my $nstr ;
	while ($ls =~ m!/\*.*?\*/!s) {
		$nstr = '';
		my $cnt = () = $& =~ /\n/sg;
		$nstr = "\n"x$cnt if $cnt;
		$ls =~ s!/\*.*?\*/!$nstr!s ;
	}
	$ls =~ s/--.*$//mg;
	my %dchk ;
	foreach my $line ($ls =~ m!\sfrom\s+([\w\s,.]+)?(?:\sWHERE\s|\sGROUP\s|\sORDER\s|[\(<;\"])|\sdelete\s.*?from\s+(?:\w+\.)*(\w+)\s|insert\s+into\s+(?:\w+\.)*(\w+)[\s(]|update\s+(?:\w+\.)*(\w+)\s+set\b!sgic ) {
		if ($line) {
			$line = uc($line) ;
			$line =~ s/^\s+|\s+$//sg ;
			$line =~ s/\s(?:GROUP|WHERE|ORDER)\s.*$//sig ;
			foreach my $tname (split(/,/, $line)) {
				$tname =~ s/^\s+|\s+$//g ;
				$tname =~ s/\s+\w+$//s ;
				$tname =~ s/^.*?\.//s ;
				next if ($tname =~ /DUAL/);
#				$tname =~ s/^(\w+)?.*/$1/s ;
	   			print $FHW ("$cdir\t$_\t$tname\n") unless ($dchk{$tname}++);
			}
		}
	}
}

sub inspect_query {
	if ($exts) { return unless /($exts)$/ ; }
	return if ( -d || /\.(txt|log|exe|pdf|bak|tar|jar|jpg|png|ico|bmp|jpeg|xpm)?$/i || /\d{8,}/ ) ;
	return if (-s > 1024*1024*20);

  	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$TOT_CNT++;
	Dawin::PRINT_1($TOT_CNT,$_) ; 
	my $cdir = $File::Find::dir;
#	$cdir =~ s!^$dir/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	local $/;
  	my $ls=<$FF> ;
    close $FF ;
	my $nstr ;
	while ($ls =~ m!/\*.*?\*/!s) {
		$nstr = '';
		my $cnt = () = $& =~ /\n/sg;
		$nstr = "\n"x$cnt if $cnt;
		$ls =~ s!/\*.*?\*/!$nstr!s ;
	}

	foreach my $line ($ls =~ m"\s((?:select|delete|update|insert)\s.*?)(?:;|<!|]]|</|{)"sgi ) {
		if ($line) {
			$line =~ s/^\s+|\s+$//sg ;
			$line =~ s/\s/ /sg ;
			$line =~ s/  / /sg ;
   			print $FHW ("$cdir\t$_\t$line\n");
		}
	}
}


sub HELP_MESSAGE(){
  print <<END;

파일내의 테이블 목록 또는 SQL문장을 추출한다.

    Usage: $0 [-q] [-o 결과파일] [-e 확장자1,확장자2..] [검색DIR]

    -q : 파일내 SQL문을 추출한다. 지정하지 않을 경우 테이블 목록을 추출.
    -o : 결과파일 : 지정한 파일로 검색결과 파일 생성
    -e : 확장자   : 지정한 확장자만 출력
   
    검색DIR은 생략시 현재DIR에서 검색시작함.
	
END
}

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
        die "\n사용자 Abort.\n";
};
