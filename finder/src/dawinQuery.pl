use warnings;
use strict;
use File::Find;
use Getopt::Std; 
use File::Basename;
use Cwd;
use IO::Handle;
use Dawin;
use Dawin_cont ;
#use DwgenHTML;
use Encode qw(from_to is_utf8) ;
use Encode::KR;

if ( Dawin::getstrdate() > '29991231' ) { print "** ��밡�ɱⰣ�� �������ϴ�. \n"; exit };

sub HELP_MESSAGE(){
  die <<END;
TABLE�� ���� Query ID �� ���Ͽ�������.

Usage: $0 [-o path] [-r 1 ~ 3 ] [ -d path ] [ -e ��Ī1,��Ī2... ] ([-f �˻��׸�����] | �˻��� )

OPTION
    -o <path>       ����� ������ dir (�������������� ����dir)
    -d <src path>  �˻���� �ҽ� root  dir
    -e <���ܸ�Ī>  �ش��Ī�� �����ϴ� ��������
    -f <�˻�����>  �˻����� ��ϵ� �ؽ�Ʈ ����
    -j utf8 => euc-kr ��ȯ
    -h view help message

�˻��׸����� : ������ �˻��׸��� ���κ��� �и�
  ��)
    �˻��׸�1
    �˻��׸�2
    .
    .
    �˻��׸�n

   * -r2, -r3 �ɼ��� �־��� ���� ���̺��� Į�������� �����Ѵ�.
    ���̺��1 Į���׸�1 
    ���̺��2 Į���׸�2 
    .
    .    
    ���̺��n Į���׸�n 

�˻�DIR�� ������ ����DIR���� �˻�������.
    
END
}

my $FHW ;

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
		my $end = time;
		printf ("\n***  �����ߴܵ� $0 : %s \n", Dawin::to_strdate(($end,"/",":")) ) ;
		die ;
};

my %myopts = ();
my ( $sfile,$dir,$odir,$wfile, $RULE, $exts, %dbHash, $Fn1, $Fn2, $fstrA, $fstrB, @Tlist, %hRSLT, %hINCL );
my $opts = "@ARGV" ;
getopts("hjse:o:r:d:f:",\%myopts) or HELP_MESSAGE() ;
if ( defined($myopts{h}) ) {
  HELP_MESSAGE();
  exit;
}

if ( defined($myopts{e}) ) {
	except_const($myopts{e}) ;
}

if ( defined($myopts{o}) ) {
	$odir = $myopts{o} ;
} else {
	$odir = getcwd() ;
}
$sfile = '';
$RULE = $myopts{r} || 1;

$dir = $myopts{d} || getcwd() ;

if ( defined($myopts{f}) ) {
	$sfile = $myopts{f} ;
	die "!! $sfile �� ã���� �����ϴ�." unless -e $sfile;
	hash_const($sfile) ;
	$wfile = $odir.'/QI0_'.basename($sfile) ;
} else {
	$dbHash{"@ARGV"} = 1;
  $fstrA = join ("|",keys %dbHash) ;
  if (defined($myopts{s})) {
  	$wfile = $myopts{s};
  } else {
  	$sfile = "".time ;
		$wfile = $odir.'/QI0_'.$sfile ;
	}
}

mkdir $odir unless -d $odir ;
die "����� ������ path($odir)�� Ȯ���ϼ���" unless -d $odir ;
die "!! �˻��� path �ٸ��� �����ϼ���." unless -d $dir;
my $logfile = dirname($0).'/dawinlog_v3.log' ;

if ( $RULE == 2 ) {
	Dawin_cont::find_run($sfile,$dir,$odir,$Dawin::Glogfile, $RULE) ;
  exit;
}
STDOUT->autoflush() ;

$dir =~ s!\\!/!g ;
my $sdir = getcwd();

Dawin::Log_start() ;

print "\n** �˻�DIR  --> $dir \n" ;
#print "** �α����� --> $logfile \n";

print "** ������� --> $wfile \n";

#my $sltm = localtime ;
#print "\n*** Start $0 : $sltm \n";

my ($SW,$TOT_CNT, %ActionJsp) = (0,0) ;
if (defined($myopts{s})) {$SW=1; goto SKIP_Q0; }
open($FHW,">",$wfile) || die "$wfile $! \n";
$FHW->autoflush() ;

if ($RULE != 1) {
	print $FHW  " TBL \t Column \t Directory \t ���α׷�ID \t line \t �˻����� \t QueryID or Class \t �����˻��� \t seq \t DML\t ����func \t func \t origin\n" ;
	$Fn1 = \&inspect_file ;
} else {
	print $FHW " �˻��׸� \t DIR \t ���α׷�ID \t �ٹ�ȣ \t �˻����� \t Query ID \n" ;
	$Fn1 = \&print_if_file ;
}

find($Fn1, $dir);

#include �� ���
for my $incl (keys (%hINCL)) {
	for my $incl2 (keys %{$hINCL{$incl}}) {
		next unless $hRSLT{$incl} ;
		for my $kk (keys %{$hRSLT{$incl}}) {
			print $FHW ("$kk\t",$hINCL{$incl}{$incl2},$hRSLT{$incl}{$kk},$RULE != 1 ? "\t\t\t$incl\n" : "\n") ;
		}
	}
}
print "\n** �۾����ϼ� ($TOT_CNT)\n" ;

close($FHW) ;

=begin comment
my $eltm = localtime ;
my $end = time;
my $diff = $end - $start;

open(my $FLOG,">>",$logfile) || die "$logfile $! \n";
$FLOG->autoflush() ;

printf ("\n***   End $0 : $eltm ## �ҿ�ð� : %d�ð� %d�� %d�� .\n",$diff/3600, int $diff%3600/60, $diff%60) ;
print  $FLOG   ("\n*** Start $0 : $sltm $sdir\n( $opts )") ;
print  $FLOG   ("\n** �۾����ϼ� ($TOT_CNT)") ;
printf $FLOG   ("\n***   End $0 : $eltm : $sfile  ## �ҿ�ð� : %d�ð� %d�� %d�� .\n",$diff/3600, int $diff%3600/60, $diff%60) ;

close($FLOG);
=cut

out_actionJsp();
SKIP_Q0:
if ($SW) {
  chdir $sdir ;
  print  "** dawin_cont start **\n" ;
  
  Dawin_cont::find_run($wfile,$dir,$odir,$Dawin::Glogfile, $RULE,\$exts) ;
  
  $wfile =~ s/qi0_/qi1_/i;
  my $ftype = $RULE == 1 ? '' : 'a' ;
=begin commect
  my $choice ;
  print "\n HTML������ �����ұ��?(y/N)> ";
  chomp ($choice = <STDIN>);
  if (lc($choice) eq "y") {
	  chdir $sdir ;
	  print  "\ndwgenHTML start **\n" ;
	  DwgenHTML::start($dir, $odir, $wfile, $ftype ) ;
  }
=cut
}
Dawin::Log_end($opts,$TOT_CNT) ;

sub out_actionJsp {
	my @kk = keys %ActionJsp ;
	return unless @kk ;
	my $wfile = $odir.'/tmp_'.basename($sfile) ;
	open(my $FACT,">",$wfile) || do {print "$wfile $!\n"; return} ;
	foreach my $key (@kk) {
		print $FACT "$key\t$ActionJsp{$key}\n" ;
	}
	close($FACT);
}

sub print_if_file {
	return if ( -d ) ;
	my ($nmSpace, @sResult, $idchk, $QID) = ("");

	if( /\.(xml|java)$/i) {
		$TOT_CNT++;
		Dawin::PRINT_1($TOT_CNT,$_) ; 
#		print "\r** �۾��� ($TOT_CNT): $_"," "x (60 - length($_)) unless ($TOT_CNT%100);
		if ( substr($_,-4) eq 'java') {
			java_if_file() ;
			return ;
		}
    open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
		$dir = $File::Find::dir;
		$dir =~ s!^\./?!! ;

  	while( my $line=<$FF>) {
  		if ($line =~ m{<(action|bean)\b}) { action_jsp($line,$FF) ; next }
			if ($line =~ m{<sqlMap\s+namespace=\"(\w+)\"}) { $nmSpace = $1."." ; next } # 20151102 namespace���� ���Խ�Ű�� ����
			
  		@sResult = ($line =~ /<(?:(?:sql|query|select|update|delete|insert) id|statement name)="?(.+?)["\s>]{1}/ );
  		if (@sResult) {
  			$QID = $sResult[0] if $sResult[0] ;
  			$QID =~ s/\"$// ;
  			next ;
  		}
#    		print STDERR "line = $line \n";
  		undef $QID if $line =~ m!</(?:sql|query|select|update|delete|insert|statement)>!i ;
  		next unless $QID ;
  		if ($line =~ m{<include\s+refid=\"([\w.]+)\"}) {  # 20151102 include�� ã�� ����
  			my $lval = $1;
	    	if (defined($myopts{j})) {
					from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
				}
  			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
				$line =~ s/\s/ /g;
				$line =~ s/  / /g;
  			
  			if ($lval =~ /\./)
  				{$hINCL{$lval}{$.} = "$dir\t$_\t$.\t$line" ;}
  			else
  				{$hINCL{$nmSpace.$lval}{$.} = "$dir\t$_\t$.\t$line" ;}
  		}
  		my @sTbl = ();
			@sTbl = ($line =~ /($fstrA)/gi) ;
			next if $#sTbl == -1 ;
			chomp($line);
			$line =~ s/^\s+//;
    	if (defined($myopts{j})) {
				from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
			}
	  	$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
			$line =~ s/[\t\r]/ /g;
			foreach my $kk ( @sTbl ) {
				printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\n", searchW($kk),$dir, $_ ,$.,$line, $nmSpace.$QID)  if $kk;
				$hRSLT{$nmSpace.$QID}{$kk} = 1;
				$SW = 1;
  		}
    }
    close ($FF) ;
	}
}

sub inspect_file {
	return if ( -d or /^(?:log4j|web)\.xml/i ) ;
	return unless (/\.(xml|java)$/i) ;
	if ( $exts ) { return if (basename($_) =~ /$exts/i) ;	}
	$TOT_CNT++;

	Dawin::PRINT_1($TOT_CNT,$_) ; 
	if ( lc(substr($_,-4)) eq 'java') {
		inspect_java_file() ;
		return ;
	}
	my ($nmSpace, @sResult, $QID, $cdir, $ls, $fchk, $fcnt, $ps, $fqid ) = ("");

	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^$dir/?!! ;

	while( my $line=<$FF>) {
		if ($line =~ m{<(action-name|action|bean)\b}) { action_jsp($line,$FF) ; next }
		if ($line =~ m{<sqlMap\s+namespace=\"(\w+)\"}) { $nmSpace = $1."." ; next } # 20151102 namespace���� ���Խ�Ű�� ����
		@sResult = ($line =~ /<(?:(?:sql|query|select|update|delete|insert) id|statement name)="?(.+?)["\s>]{1}/i );
		if (@sResult) {
			$QID = $sResult[0] if $sResult[0] ;
			$QID =~ s/\"$// ;
			next ;
		}
		next unless $QID ;
		$ls = '';
		$fqid = $nmSpace.$QID;
		until ($line =~ m!</(?:sql|query|select|update|delete|insert|statement)>!i  or eof($FF) ) {
			$ls .= $line ;
  		if ($line =~ m{<include\s+refid=\"([\w.]+)\"}) {  # 20151102 include�� ã�� ����
  			my $lval = $1;
	    	if (defined($myopts{j})) {
					from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
				}
  			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
				$line =~ s/\s/ /g;
				$line =~ s/  / /g;
  			
  			if ($lval =~ /\./)
  				{ $hINCL{$lval}{$.} = "$cdir\t$_\t$.\t$line\t$fqid\t\t0\t" ; }
  			else
  				{ $hINCL{$nmSpace.$lval}{$.} = "$cdir\t$_\t$.\t$line\t$fqid\t\t0\t" ; }
  		}
			$line=<$FF> ;
		}
		
		foreach my $kk ( keys %dbHash ) {
			$fcnt = 0;
			$fchk = 0;
			undef $ps ;
			foreach my $item ( split /\s/,$kk ) {
				$fcnt++ ;
  				if ($ls =~ /\W$item\W/is) {
  					$fchk++ ; 
  					$ps = $-[0] if ( !defined($ps) or $ps > $-[0]); 
  				} 
			}
			if ($fcnt > 0 and $fcnt == $fchk) {
				my $ln = (substr($ls,$ps) =~ tr/\n//) ;
				substr($ls,0,$ps) =~ /.*\n/s ;
				$line = substr($ls,$+[0],140) ;
				$line =~ s/(.*)\s/$1/;
				$line =~ s/^\s+|\s+$//sg;
	    	if (defined($myopts{j})) {
					from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
				}
  			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
				$line =~ s/\s/ /g;
				while ($line =~ s/  / /g){}
				my $lscrud = '';
				{ $ls =~ /\b(SELECT|UPDATE|DELETE|INSERT)\b/i and $lscrud = uc($1); }
				$kk =~ s/\s+/\t/ ;
				
				printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\t\t0\t$lscrud\t\t\t%s\n", $kk ,$cdir, $_ ,$. - $ln ,$line , $fqid, $fqid) ;
				$hRSLT{$fqid}{$kk} = $lscrud;
				$SW = 1;
			}
		}
		undef $QID;
  }
  close ($FF) ;
	return ;
}

sub java_if_file {
    open (my $FF,$_) or  print STDERR "\n** ERROR: $_ $!\n" and return ;
		my $cdir = $File::Find::dir;
		$cdir =~ s!^$dir/?!! ;
		$cdir =~ s!^\.{1,2}/?!! ;
#		$/ = "\n";
    while(my $line=<$FF>) {
    	next if ($line =~ m!^\s*(?:\*|--|//|/\*|package|import)!) ;
			chomp($line) ;
			my @sTT = ();
			@sTT = ($line =~ /[\s\W]($fstrA)[\s\W]/igo) ;
			next if $#sTT == -1 ;
    	if (defined($myopts{j})) {
				from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
			}
			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
			$line =~ s/^\s+|\s+$//g;
			$line =~ s/\s/ /g;
			$line =~ s/  / /g;

			foreach my $kk ( @sTT ) {
				printf $FHW ("%s\t%s\t%s\t%d\t%s\n", searchW( $kk ),$cdir, $_ , $. , $line) if $kk;
				$SW = 1;
    	}
    }
    close $FF ;
}

sub inspect_java_file {
    	open (my $FF,"<",$_) or  print STDERR "\n** ERROR: $_ $!\n" and return ;
    	my ($cdir, %itemA, %itemB, $fcnt,$fchk, $ln,$pos,$pos2, $s_ln, $method , $lscrud) ;
		$cdir = $File::Find::dir;
		$cdir =~ s!^$dir/?!! ;
		$cdir =~ s!^\.{1,2}/?!! ;
		local $/;
    	my $ls=<$FF> ;
	    close $FF ;
 
 # �ּ��κ����� �ٸ� LF�� ���ܵ�
  my $nstr ;
	while ($ls =~ m!(/\*.*?\*/)!s) {
		$nstr = $1;
		$nstr =~ tr/\n//csd;
		$ls =~ s!!$nstr!s ;
	}
	while ($ls =~ s!(?>//|--).*?$!!mg) {}
	
 # �ּ����ų�
 
	foreach my $kk ( keys %dbHash ) {
		$pos2 = 0;
		$s_ln = 0;
		my ($tbl,$item)  = ( split /\s/,$kk ) ;

		next unless ( $ls =~ /\b$item\b.*?\b$tbl\b|\b$tbl\b.*?\b$item\b/si ) ;
		my $line = $ls ;
		my ($val,$lcnt,$rcnt) ;
		while ( $line =~ qr!^\s*[^/\*\x80-\xff].*?\W($item|$tbl)\W!mi ) {
			$val = $1;

			$pos2 += $-[1];
			last if $-[1] == 0 ;

			$pos = $pos2;
			$pos2 += 3 ;
			$line = substr($line,$-[1]) ;

#			$pos2 += $-[0] if $line =~ /\n/ ;

			while ($line =~ qr!(?>.*?)(}|\Z)!s) {
				$line = substr( $line,0,$-[1] ) ;
				$lcnt = ($line =~ tr/{//);
				$rcnt = ($line =~ tr/}//);
				last if ( $lcnt  == $rcnt ) ;
			}

#			$line =~ s/UNION/}/g ;
			if ( uc($val) eq uc($tbl) ) {
				unless ($line =~ /^[^\/\*][^}]*?\W($item)\W/si) {
					$line = substr($ls,$pos2 ) ;
					next ;
				}
				$pos += $-[1];
			} else {
				unless ($line =~ /^[^\/\*][^}]*?\W$tbl\W/si) {
					$line = substr($ls,$pos2 ) ;
					next ;
				}
			}

			$line = substr($ls,0,$pos) ;
			$ln = ($line =~ tr/\n//) ;
			$ln++ ;

#			{ 
#			  if ( my @marr = ($line =~ /\s+public\s+[^({=]*?\s+(\w+)\s*\(/sgo)) { $method =  $marr[$#marr]; $method = '' if ($method eq 'main') ;}
#			}
			$method = "";
			{ $line =~ /(?>.*)\bpublic\s+[^({=]*?\s+\(/so and $method = $1 ; }
			$lscrud = "";
			{ $line =~ /(?>.*)\b(MERGE|SELECT|UPDATE|DELETE|INSERT)/si and $lscrud = $1 ;}

#			$pos = $+[0] if ($+[0]) ;
#			$line = substr($ls,$pos,100) ;
			$line =~ /.*\n/s ;
			$line = substr($ls,$+[0],140) ;
			$line =~ s/(.*)\s/$1/;
			$line =~ s/^\s+|\s+$//g;
    	if (defined($myopts{j})) {
				from_to($line ,"utf8", "euc-kr") if (is_utf8($line));
			}
			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
			$line =~ s/\s/ /g;
			$line =~ s/  / /g;
    		
			$method = '' unless $method ;
			printf $FHW ("$tbl\t$item\t%s\t%s\t%d\t%s\t%s\t%s\t0\t$lscrud\n", $cdir, $_ ,$ln ,$line, substr($_,0,-5), $method ) if ($s_ln != $ln);
    		
    		$s_ln = $ln ;
    		$line = substr($ls,$pos2 ) ;
    		$SW = 1;
		} 
	}
	return ;

}

sub action_jsp {
	my ($Data,$FF) = @_ ;
	if ( $Data =~ /action-name /) {
    	until ($Data =~ m{</action-name>}s) { last unless ($Data .= <$FF>) ;  } ;
    	my @getrst = ($Data =~ m{(?:path|url|name)="(.+?)["\s]{1}.* (?:<command>).*\.(.+?)</command>}s) ;
    	return if (@getrst < 2) ;
    	$ActionJsp{$1}=$2 ;
	
	} else {
    	until ($Data =~ m{<(action|bean)\b.*>}s) { last unless ($Data .= <$FF>) ;  } ;
    	my @getrst = ($Data =~ m{(?:path|url|name)="(.+?)["\s]{1}.* (?:type|class)=".*\.(.+?)["\s>]{1}}s) ;
    	return if (@getrst < 2) ;
    	$ActionJsp{$1}=$2 ;
	}
}

sub searchW($) {
	my ($item,$tg) ;
	$tg = $_[0] ;
	foreach $item (@Tlist) {
		return $item if $tg =~ /$item\b/i ;
	}
	return  ;
}
sub hash_const {
    my $sfile = shift; 
	if ($RULE != 1) {return hash_const_2item($sfile) }

    open(FL,$sfile) || die "$sfile $! \n";
    @Tlist = Dawin::trim(<FL>) ;
    close(FL) ;

    chomp(@Tlist);
    @Tlist = sort {length($b) <=> length($a)} @Tlist ;
    #print STDERR (join "\n",@Tlist) ;
    my @Tlist2 = map { length($_) <= 2 ? '\b(?:[gs]et)*'.$_.'\b' : $_.'\b' } @Tlist ;
    $fstrA = join ("|",@Tlist2) ;
    $fstrA =~ s/\$/\\\$/g ;

}

sub hash_const_2item {
    my $sfile = shift;
    my @items ;
    open (my $IN,"<",$sfile) || die "$sfile $! \n";
    while(<$IN>)
    {
    	next if (/DIR.+�˻�����/) ;
        chomp;
        s/^\s+|\s+$//g;
        @items = (split(/\s/, $_))[0,1];
        @items = Dawin::trim(@items);
		next if (scalar(@items) < 2) ;

    	$dbHash{$_} = \@items ;
    }
    
    close $IN;
    my (@lstA, @lstB) ;
    for my $kk (keys %dbHash) {
    	push(@lstA, $dbHash{$kk}->[0]);
    	push(@lstB, $dbHash{$kk}->[1]);
    }
	@lstA = sort {length($b) <=> length($a)} @lstA ;
	@lstB = sort {length($b) <=> length($a)} @lstB ;
    $fstrA = join ("|",@lstA) ;
    $fstrA =~ s/\$/\\\$/g ;
    $fstrB = join ("|",@lstB) ;
    $fstrB =~ s/\$/\\\$/g ;
	
}

sub except_const {
    my $sfile = shift;
	if (-e $sfile) {
		open(FL,$sfile) || die "$sfile $! \n";
		my @Elist = Dawin::trim(<FL>) ;
		close(FL) ;
		chomp(@Elist);
		$exts = join("|", sort {length($b) <=> length($a)} @Elist) ;
	} else {
		$exts = $sfile ; # =~ s/\./\\./gr ;
		$exts =~ s/,/|/g ;
	}
}

sub VERSION_MESSAGE(){
  print "$0 Version 1.2 danielpk62\@dawinit.com";
}
