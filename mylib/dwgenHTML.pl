use warnings;
use strict;
use Getopt::Std; 
use DwgenHTML ;

my %myopts = ();

getopts("aho:d:f:",\%myopts) or HELP_MESSAGE();
if (defined($myopts{h}) ) {
  HELP_MESSAGE();
}  

my ($wdir, $src_path);
my $ftype = $myopts{a} || ' ' ;

$wdir = $myopts{o} || '.' ;

$src_path = $myopts{d} || '';

my ($sfile) = $myopts{f} || HELP_MESSAGE();

die "!! $sfile 를 찾을수 없습니다." unless -e $sfile;

DwgenHTML::start($src_path, $wdir, $sfile, $ftype ) ;

sub HELP_MESSAGE{
  die <<END;

탭으로 분리된 검색결과 파일내용을 기준으로 HTML파일을 생성한다.
Usage: $0 [-a] [-o 출력Dir] [-d 소스기준dir] -f 검색결과파일

-a  : 연관검색결과파일 처리(9개항목)
-o 출력Dir : 지정한 dir에 html 생성
-d 소스기준Dir : 소스파일의 위치 root
-f 검색결과파일 : 탭으로 분리된 CSV파일(첫번째라인을 title로 처리함)
  형식)
    * 기본
     TBL 	 COL 	 DIR 	 파일명 	 줄번호 	 검색내용 	 코드값 
	* 연관검색 ( -a 옵션 )
     TBL 	 COL 	 DIR 	 파일명 	 줄번호 	 검색내용 	 Class	연관검색값	차수 

END
}

