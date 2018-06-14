use warnings;
use strict;
use File::Find;
use File::Basename;
#use File::Path qw(make_path );
use Getopt::Std; 
use IO::Handle;
use Dawin;

my $Fn = sub {} ;
my %myopts = ();
my ($wfile,$excl, $incl);

getopts("htco:e:i:",\%myopts);

#if ( defined($myopts{c}) ) {
	$Fn = \&Dawin::ExtCount ;
#}

if ( defined($myopts{o}) ) {
	$wfile = $myopts{o} ;
}

if ( defined($myopts{e}) ) {
	$excl = $myopts{e} ;
}
if ( defined($myopts{i}) ) {
	$incl = $myopts{i} ;
}

if ( defined($myopts{h}) ) {
	&HELP_MESSAGE();
	exit;
}	

my @dir = ('.')  ;
@dir = map { glob } @ARGV  if (@ARGV > 0) ;

print "검색 directory --> $dir[0]\n";

my $TOT_CNT = 0 ;
$Fn->('init') ;

my ( $FHW,$ext ) ;
my	$Fn1 = \&print_if_file ;
STDOUT->autoflush() ;
if ( defined($wfile) ) {
  print "** 결과파일 --> $wfile \n";
  open($FHW,">",$wfile) || die "$wfile $! \n";
}  else {$FHW = *STDOUT;}
$FHW->autoflush() ;

if  ( ! defined($myopts{c}) ) {
	print $FHW " DIR \t 파일명 \t 확장자 \t 사이즈 \t 수정일 " ;
	if (defined($myopts{t})) {
		print $FHW "\t 내용설명 \n" ;
	} else {
		print $FHW "\n" ;
	}
}

find($Fn1, @dir);

if ( defined($wfile) ) {
  close($FHW) ;
}

$Fn->('print') unless (defined($myopts{x}));

sub print_if_file {
	return if ( -d $_ ) ;
	if ($incl) { return unless /$incl/ ; }
	if ($excl) { return if /$excl/ ; }
	
	$Fn->('count',$_) ;
	return if ( defined($myopts{c}) );

	my $sz = -s ;
	my $ldir = $File::Find::dir;
	my $mdate = Dawin::to_strdate( (stat($_))[9], "-",":");
#	$ldir =~s!^$dir/?!! ;
	$ldir =~ s!^\.{1,2}/?!! ;
	($ext) = ($_ =~ /.*\.(.*)$/) ;
	$ext = '' unless $ext ;
	printf $FHW ("%s\t%s\t%s\t$sz\t%s", $ldir, $_ , $ext, $mdate );
	if ( defined($myopts{t}) ) {
		my @rmk = search_title() ;
		print  $FHW "\t$rmk[0]\t@rmk[1..$#rmk]" ;
	}
	print $FHW "\n" ;
}

sub search_title {
	my @res = (' ') ;
	return @res if (-s > 1024*1024*20);
 	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;

	my $ls = "";
	if ( /htm$/ ) {
		local $/  ;
		$ls = <$FF> ;
#		@res = (($ls =~ /ncDoc_setTitle\(\s*"(.*?)"/s or $ls =~ /설\s*명\s*:?(.*)$/m) ,  $ls =~ /program_id"\s*,\s*"(.*?)"/mg ) ;
#		$ls =~ /ncDoc_setTitle\("(.*?)"/m ;
#		unshift(@res, $1) ;
	} else {
		foreach (1..60) {
			$ls .=<$FF> || last ;
		}
		$ls =~ /설\s*명\s*:\s*(.*)\*?.*?$/m ;
		$ls =~ /시스템\s*명\s*:\s*(.*)\*?.*?$/m unless ($1) ;
		$ls =~ /프로그램\s*명\s*:\s*(.*)\*?.*?$/m unless ($1) ;
		$res[0] = $1 ;
	}
    close $FF ;
	foreach (@res) { s/\s/ /g if ($_) ;} 

	$res[0] = ' ' unless $res[0] ;
	return @res ;
}

sub HELP_MESSAGE(){
  print <<END;

지정된 디렉토리의 파일리스트를 출력한다.

    Usage: $0 [[-c][-t]] [-o 결과파일] [-i patten] [-e patten] [검색DIR...]

    -c : 확장자별 파일수 집계만 출력
    -t : 내부설명내용 출력(설명, 시스템명, 프로그램명을 찾아 내용 표시)
    -o : 결과파일 : 지정한 파일로 검색결과 파일 생성
    -i : 지정한 패턴에 일치되는 파일만 출력
    -e : 지정한 패턴에 일치되는 파일을 제외하고 출력
   
    검색DIR은 생략시 현재DIR에서 검색시작함.
	
END
}

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
        die "\n사용자 Abort.\n";
};
