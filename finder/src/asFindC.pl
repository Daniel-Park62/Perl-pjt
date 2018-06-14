# DAWIN ICT. ���ο�
use warnings;
use strict;
use File::Find;
use File::Basename;
use Getopt::Std; 
use IO::Handle;
use Encode qw(from_to is_utf8) ;
use Dawin;

sub HELP_MESSAGE(){
  die <<END;

�ҽ� ������� �м��Ѵ�.

 Usage: $0 [-bc][-e �˻����Խ�][-k ȣ���������][-o �������] [-s�ҽ����ϸ� ][-d �˻�DIR1,�˻�DIR1,..]

 OPTION
    -d : �˻����丮 (������ ����DIR���� �˻�����)
    -e : ���ԽĿ� ���� �˻�
    -L : include dir (, �� �и��Ͽ� �ټ���������))
    -k : ȣ������������� || ctag����(-n �ɼ�������)
    -n : -k ������ call��� �ۼ��ɼ�
    -o : ������� : ������ ���Ϸ� �˻���� ���� ���� (������ ȭ�����)
	
	** ��������� Ȯ���ڰ� xml �ΰ�� xml�������� ���ϻ���.
	   �� �ܴ� tab���� ���е� csv�������� ������.
	
END
}

my %myopts = ();
my ($fm_flag, $wfile,$rdir, @sdir, @incldir, %call_func, %Next, %Curr, %called ,%chkM, %chkP) = (0);
my $findstr = '(?>/\*\s*���������Ϻ�ȣȭ_201[56].\s*START)\s.*?\*/(?:/\*.*?\*/)*\s*(.*?)/\*\s*���������Ϻ�ȣȭ_201[56].\s*END\s*.*?\*/';

my $incl_file_sub; # include file ���
$incl_file_sub = sub  {
  my ($fname, $href) = @_;
	my $fh ;
	foreach my $ldir (@incldir) {
		my $full_nm = $ldir."/".$fname ;
		if ( -f $full_nm ) { open ($fh, $full_nm) ; last ; }
	}
	return unless ($fh) ;
	while (<$fh>) {
		if (/^\s*#include\s+\"(\w+\.h)\"/) {
			print "recuresive call $1\n";
			$incl_file_sub->($1,$href) ;
			next ;
		}

		while ( /\s(?:int|integer|long|short)(?:\*\s+|\s+\*)\s?((?>\w+))\s*[^(]/g) {
		 $href->{$1} = $fname ;
		}
		;
	}
	close $fh ;
	
} ;

my $mfilenm;  
my $parm = "@ARGV" ;
print "@ARGV","\n";

if ( Dawin::getstrdate() > '29991231' ) { print '** ��밡�ɱⰣ�� �������ϴ�.!! \n'; exit };

getopts("d:e:f:g:hjL:o:",\%myopts) or &HELP_MESSAGE();;

if ( defined($myopts{h}) ) {
	&HELP_MESSAGE();
	exit;
}	

if ( defined($myopts{e}) ) {	$findstr="(".$myopts{e}.")" ; }	

if ( defined($myopts{o}) ) {	$wfile = $myopts{o} ; }

if ( defined($myopts{d}) ) {
	$myopts{d} =~ s!\\!/!g  ;
	@sdir = grep { -d } map { glob} split(/[, ]/,$myopts{d} ) ;
	print "�˻� dir --> @sdir\n";
} else { @sdir = ('.') ; }
$rdir = join ('|',@sdir) ;

if ( defined($myopts{L}) ) {
	$myopts{L} =~ s!\\!/!g  ;
	@incldir =  grep { -d } map { glob } split(/,/,$myopts{L}), "."  ;
	print "include dir --> @incldir\n";
} else { @incldir = ('.') ; }

our ($Fn, $TOT_CNT, $FHW, $ctags ) = (\&search_file, 0) ;
STDOUT->autoflush() ;

if ( defined($wfile) ) {
  print "** ������� --> $wfile \n";
  open($FHW,">",$wfile) || die "$wfile $! \n";
  $fm_flag = 1 if ($wfile =~ /\.xml$/i) ;
}  else {$FHW = *STDOUT;}

Dawin::Log_start() ;

$FHW->autoflush();
if ( defined($myopts{b}) )  {
	$Fn = \&optB_func_deflist ;
} elsif ( defined($myopts{k}) )  
{
	$Fn = \&search_func_call ;
	open (my $FF,$myopts{k}) or print STDERR "\n** ERROR: $myopts{k} $!\n" and return ;
	local $/;
	$ctags=<$FF> ;
	close $FF ;
	print $FHW ("�˻�����","\t�Լ���","\t���ϸ�","\tȣ���Լ���","\tȣ�����ϸ�","\t����\n") unless ( defined($myopts{n}) )  ;
} else {
	if ($fm_flag) {
		print $FHW '<?xml version="1.0" encoding="euc-kr" standalone="yes"?>' ;
		print $FHW "\n<!-- ** �ҽ������ ���� ** -->\n" ;
		print $FHW "\n<!-- �˻���[$findstr] -->\n" ;
		print $FHW "<dawininc>\n" ;
	} else {
		print $FHW ("Directory\t","���ϸ�\t","line\t","����\t","�Լ�\n") ; 
	}
}

if ( defined($myopts{f}) && defined($myopts{k}) ) 
{
	search_master( read_funcName( $myopts{f} ) ) ;
} elsif ( defined($myopts{s}) && defined($myopts{k}) ) 
{
#	defined($myopts{n}) ? func_call_list($myopts{s} ,1) : func_call($myopts{s} ,1) ;
	defined($myopts{n}) ? func_call_list($myopts{s} ,1) : search_master( [$myopts{s}] ) ;
} else
{
	find({wanted=>$Fn,no_chdir=>0} , @sdir);
}

my $sq = 1;
while ( scalar(keys %Next) > 0 )
{
	%Curr = () ;
	foreach my $kk ( keys %Next )
	{
		$Curr{$kk} = $Next{$kk} ;
	}
	%Next = () ;
	$sq++ ;
	print "\n",$sq," th\n";
	$TOT_CNT=0;
	foreach my $vv ( values %Curr )
	{
		$TOT_CNT++;
#		printf ($fmt,$TOT_CNT,$vv) ; 
		func_call($vv,$sq) ;
	}
}
print "\n";

if ($fm_flag) {
	print $FHW "\n</dawininc>\n" ;
	print $FHW "\n<!-- **  �ҽ������ �������� ($TOT_CNT �� �˻�) ** -->\n" ;
}

close($FHW) if ( defined($wfile) ) ;

Dawin::Log_end($parm,$TOT_CNT) ;

sub search_file {
	return if (-d or ! /[p.]c$/);

	my $sz = -s ;
	return if ($sz > 1024 * 1024 * 10 );

	my $ldir = $File::Find::dir;
#	$ldir =~s!^$rdir/?!! ;
	$ldir =~ s!^\.{1,2}/?!! ;

	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$TOT_CNT++;

	Dawin::PRINT_1($TOT_CNT,$File::Find::name) ; 

	local $/;
	my $lsrc=<$FF> ;
	close $FF ;
	my ($pp,$ln,$tmp,$fnm,%inclsrc, $nstr, $cnt) = (1,0);
	
	while ($lsrc =~ m!(/\*.*?\*/)!s) {
		$nstr = $1;
		$nstr =~ tr/\n//csd;
		$lsrc =~ s!!$nstr!s ;
	}
	while ($lsrc =~ m!(\soutlog\s*\(.*?\)\s*?;)!s) {
		$nstr = $1;
		$nstr =~ tr/\n//csd;
		$lsrc =~ s!!$nstr!s ;
	}

	while ($lsrc =~ s!(?>//|--).*?$!!mg) {}
	while ($lsrc =~ m!(\#if\s+0[^#]*?\#else)!s) {
		$nstr = '';
		$cnt = ($1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$lsrc =~ s!!#if 1 $nstr!s ;
	}
	while ($lsrc =~ m!(\#if\s+1[^#]*?)(\#else\s[^#]*?\#endif)!s) {
		last unless $2 ;
		$nstr = '';
		$cnt = ($2 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$lsrc =~ s!!$1 $nstr#endif!s ;
	}
	while ($lsrc =~ m!(\#if\s+0[^#]*?\#endif)!s) {
		$nstr = $1;
		$nstr =~ tr/\n//csd;
		$lsrc =~ s!!$nstr!s ;
	}
#	while ($lsrc =~ s!^[\t ]*\#[^#]*?$!!mg) {}
	
	while ($lsrc =~ /^\s*#include\s+\"(\w+\.h)\"/msg) {
		$incl_file_sub->($1,\%inclsrc) ;
	}
	while ($lsrc =~	/\s(?:int|integer|long|short)(?:\s+|\*\s+|\s+\*)\s?((?>\w+))\s*[^(]/sg) {
		$inclsrc{$1} = $_ ;
	}
	
	return unless (%inclsrc) ;
	my $varlist = join("|", keys %inclsrc) ;
	my ($utype,$line) ;
	while  ($lsrc =~ m!( (?:($varlist)\b[^;{}]*(?:<<|>>).*?[{};]| 
	                        (?:memcpy|strncpy|memcopy)\s*\([^)]*($varlist)\s*,.*?; |  # �׽�Ʈ ����
	                        \(\s*char\s*\*\s*\)\s*\&?($varlist)\b[^;{}]*[+-].*?[{};]|
	                        (sin_port)\s+=.*?;)
	                 )!sgx 
	        ) {
   	$line = $1;
   	$utype = $2 if $2;
# 		next if ($line =~ /sin_port.*hton/s);
  	if (defined($myopts{j})) {
			from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
		}
		
		$fnm = "";
		$tmp = substr($lsrc,0,$-[1]) ;
		$ln =  ( $tmp =~ tr/\n//) + 1 ;
		unless ($fnm = ($line =~ /int\s+(\w+)\s*\([^;]*?\)\s*\{/sg )) 
				{ while ($tmp =~ /int\s+(\w+)\s*\([^;]*?\)\s*\{/sg ) { $fnm = $1; } }

		if ($fm_flag) {
			print $FHW '<records ���ϸ�="'.$File::Find::name.'" size="'.$sz.'" �ٹ�ȣ="'.$ln.'">',"\n" ;
			print $FHW ("<��������><![CDATA[\n$line]]>\n</��������>\n");
			print $FHW ("<�Լ�>$fnm</�Լ�>\n");
			print $FHW "</records>\n" ;
		} else {
			$line =~ s/\s/ /g;
			while ($line =~ s/  / / ){}

			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
			print $FHW ($File::Find::dir,"\t",basename($File::Find::name),"\t",$ln,"\t",$line,"\t",$fnm,$utype ? $utype."\n" : "\n") ;
		}
	}
}


sub line_check {
  my $arg = shift;
	my $findstr = '(?>/\*\s*���������Ϻ�ȣȭ_201[56].\s*START)\s(.*?)/\*\s*���������Ϻ�ȣȭ_201[56].\s*END\s*.*?\*/';

  my ($ln, $ln2, $ln3, $line ,$lsrc ) ;
  $lsrc = ${$arg->{sdata}} ;

	$ln =  ( $lsrc =~ tr/\n//) + 1;
	$ln2 = 0;
	while  ($lsrc =~ m!$findstr!sgi ) {
		$line = $1;
		$ln3 =  ( $line =~ tr/\n//) + 1;
		$ln2 += $ln3 ;
	}
	print $FHW ($File::Find::name,"\t",${$arg->{pname}},"\t",$ln,"\t",$ln2,"\n") ;
}

sub optB_func_deflist {
	return if ( -d or $_ !~ /\.(?:pc|java)$/i) ;

	local $/;

	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$TOT_CNT++;
#	printf ($fmt,$TOT_CNT,$File::Find::name) ; 

  my ($item, $line ,$lsrc, $clsnm, %myFunc ) ;
  $lsrc = <$FF>;
  close $FF;
	while ($lsrc =~ s!/\*.*?\*/!!s) { }
	while ($lsrc =~ s!(?>//|--).*?$!!mg) {}
	$lsrc =~ /^\s*public\s+class\s+(\w+)\s/m and $clsnm = $1;
	while ($lsrc =~ /\s(\w{7,})\s*\([^;{]*\).*?[;{]/sg) {
		$item = $1 ;
  	if ( (substr($&,-1) eq "{") && ($& !~ /^.+[=<>!]{1,}.+$/s )) 
  	{ 
  		next if ( $myFunc{$item}++ ) ; 
			printf $FHW ("%s\t%s%s",$item, $File::Find::name, ($clsnm) ? "\t".$clsnm."\n" : "\n" )  ;
		}		
	}

}

sub search_func_call {
	return unless (/\.(?:pc|java)/i) ;
	$TOT_CNT++;
#	printf ($fmt,$TOT_CNT,$File::Find::name) ; 
	if ( defined($myopts{n}) )  {
		func_call_list($File::Find::name,1) ;
	} else {
		func_call($File::Find::name,1) ;
	}
}

sub func_call {
	my ($flnm,$sq) = @_ ;
	my $fname = basename($flnm) ;
	my ($pgid) = split('\.',$fname) ;
	my ( $src,$src1,$cdir,$item,$pos, $ln,$lncnt ) ;
	local $/;
	open (my $FF,$flnm) or print STDERR "\n** ERROR: $flnm $!\n" and return ;
	$cdir = dirname($flnm);
	$cdir =~ s!^\.{1,2}/?!! ;
	$src = <$FF>;
	close $FF;
	$lncnt = ( $src =~ tr/\n//);
	while ($src =~ s!\#if\s+0[^#]*?\#else!#if 1!s) {}
	while ($src =~ s!(?:\#if\s+0.*?\#endif|/\*.*?\*/)!!sg) {}
	while ($src=~ s!(\#if\s+1[^#]*?)(\#else\s[^#]*?\#endif)!$1\n#endif!s) {}

	while ($src =~ s!(?:\soutlog\s*\(.*?\)\s*;)!!sg) {}
	while ($src =~ s!(?:\sSPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!!sgi) {}
	while ($src =~ s!//.*?$!!mg) {}
	return unless (( $src =~ /\s(main|$pgid)\s*\(.*?\)\s*{/s) or ($src =~ /\w+\s+(\w{9,})\s*\(.*?\)\s*{/s) );
#	$src1 = substr($src,0, $+[0]);
	$src  = substr($src, $+[0]);
  while ($src =~ /(\w{9,})\s*\(.*?\)\s*[^{]/sg) {
		$item = $1 ;
		next if ($call_func{$item}++) ;
		if ($ctags =~ /^($item)\s+([^\s]+)?\s/ms)
		{
			next if ($2 =~ /$fname$/) ;
			next if ($2 =~ m!/comif/!) ;
			my $srcnm = $2 ;
			{ $srcnm =~ s!.*/!! ;}
			unless ( $called{$srcnm} )
			{
				$Next{$srcnm} = $2 ;
				$called{$srcnm} = $2 ;
			}
			printf $FHW ("$cdir\t$fname\t$lncnt\t$item\t$srcnm\t$sq\n" )  ;
			$lncnt = '';
		}		
	}
}

sub func_call_list {
	my ($flnm,$sq) = @_ ;
	my $fname = basename($flnm) ;
	my ($pgid) = split('\.',$fname) ;
	my ( $src,$src1,$cdir,$item,$ps ) ;
	local $/;
	open (my $FF,$flnm) or print STDERR "\n** ERROR: $flnm $!\n" and return ;
	$cdir = dirname($flnm);
	$cdir =~ s!^\.{1,2}/?!! ;
	$src = <$FF>;
	close $FF;
	while ($src =~ s!\#if\s+0[^#]*?\#else!#if 1!s) {}
	while ($src =~ s!(?:\#if\s+0.*?\#endif|/\*.*?\*/)!!sg) {}
	while ($src=~ s!(\#if\s+1[^#]*?)(\#else\s[^#]*?\#endif)!$1\n#endif!s) {}

	while ($src =~ s!(?:\soutlog\s*\(.*?\)\s*;)!!sg) {}
	while ($src =~ s!(?:\sSPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!!sgi) {}
	while ($src =~ s!//.*?$!!mg) {}
	return unless ( $src =~ /\s(main|$pgid|\w{9,})\s*\([^;]*?\)\s*{/s) ;
	
	my %mydef;
  while ($src =~ /(\w{9,})\s*\([^;{]*\).*?[;{]/sg) {
		$item = $1 ;
  	if ( (substr($&,-1) eq "{") && ($& !~ /^.+[=<>!]{1,}.+$/s )) 
  	{ 
  		next if ( $mydef{$item}++ ) ; 
		}		
	}
		
	my (%call_fn, $myfunc) ;
	$myfunc = $1 ;

	$src1  = substr($src, $+[0]);
  while ($src1 =~ /(\w{9,})\s*\([^;{]*\).*?[;{]/sg) {
		$item = $1 ;
		$ps = $-[0] ;
  	if ( (substr($&,-1) eq "{") && ($& !~ /^.+[=<>!]{1,}.+$/s )) 
  	{ 
  		$myfunc = $item ; 
  		next ;
  	}

		if ( $mydef{$item} ) 
		{
			next if ($call_fn{$myfunc."\t".$item}++) ;
			printf $FHW ("$myfunc\t$flnm\t$item\t$flnm\n" )  ;			
		} elsif ($ctags =~ /^($item)\s+([^\s]+)?\s/ms)
		{
			next if ($2 =~ m!/comif/!) ;
			
			my $srcnm = $2 ;
			
#			{ substr($src1,0,$ps) =~ /.*[^(]\s+(\w{9,})\s*\([^;]*?\)\s*\{/s  and $myfunc = $1 ;}
			next if ($call_fn{$myfunc."\t".$item}++) ;
			printf $FHW ("$myfunc\t$flnm\t$item\t$srcnm\n" )  ;
		}		
	}

}

sub read_funcName {
	my $sfile = shift;
	open(my $INF,"<",$sfile) or die "$! \n";
	local $/;
	my @flist = split(/\n/,<$INF>) ;
	close($INF);
	return \@flist ;
}
sub search_master {
	my $plist = shift ;

	foreach my $ea ( @{$plist} ) {
		my ($fl,$mt) = (split(/\s+/,$ea), '\w+') ;
		$TOT_CNT++;
#		printf ($fmt,$TOT_CNT,  $mt eq '\w+' ? $fl : $fl.' - '.$mt) ; 
		%chkM = ();
		%chkP = ();
		$mfilenm = $fl ;
		func_called_report($fl,$mt,-1) ;
		func_call_report($fl,$mt,1) ;
	}			

}

sub func_call_report {
	my ($flnm,$method, $sq) = @_ ;
	my $fname = basename($flnm) ;
	my ($pgid) = split('\.',$fname) ;
	my %calls = () ;
  my ($mt, $ft) ;
#  return unless ($ctags =~ /^(?>$method\s+)[^\s]*?$fname/m);
  while ($ctags =~ /(?>^($method)\s+[^\s]*?($fname)\s+(\w+)\s+([^\s]*)$)/mg) {
		$mt = $3 ;
	  $ft = basename($4) ;
	  next if ($ft =~ 'ZzGetDate.pc') ;
		next if ($calls{$ft."\t".$mt}++) ;
		$chkP{$2."\t".$1}++ ;
		printf $FHW ("$mfilenm\t$1\t$2\t$3\t$ft\t$sq\n" )  ;
	}
  if ($sq <= 20) {
		foreach my $vv ( keys %calls ) {
			func_call_report( split(/\s/,$vv), $sq + 1 ) unless $chkP{$vv};
		}
	}
}

sub func_called_report {
	my ($flnm,$method, $sq) = @_ ;
	my $fname = basename($flnm) ;
	my ($pgid) = split('\.',$fname) ;
	my %calls = () ;
  my ($mt, $ft) ;
#  return unless ($ctags =~ /\b$fname\s/s);

  while ($ctags =~ /(?>^(\w+)\s+([^\s]*)\s+($method)\s+[^\s]*($fname)$)/mg) {
		$mt = $1 ;
	  $ft = basename($2) ;
	  if ( substr($ft,0,3) ne "sp_" )
	  {
			next if ($calls{$ft."\t".$mt}++  or $ft =~ 'ZzGetDate.pc' ) ;
		}
		$chkM{$4."\t".$3}++ ;
		printf $FHW ("$mfilenm\t$1\t$ft\t$3\t$4\t$sq\n" )  ;
	}
  if ($sq >= -20) {
		foreach my $vv ( keys %calls ) {
			func_called_report( split(/\s/,$vv), $sq - 1 ) unless $chkM{$vv};
		} 
	}
}

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
        die "\n����� Abort.\n";
};

