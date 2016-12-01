use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Path qw(make_path );
use Getopt::Std; 
use IO::Handle;
use File::Basename;
use Dawin;
#use DwgenHTML;
use Encode qw(from_to is_utf8) ;
use Encode::KR;

use constant SELECT_ALL => 'SELECT\s+(?:\w\.)?\*\s+into\s[^;(]*?';
use constant SELECT_ALLJ => 'SELECT\s+(?:\w\.)?\*\s+(?:FROM|INTO)\s[^(<]*?';
use constant INSERT_ALL => '\s+VALUES';

my $regex1 = qr/.*[;{].*?[\s\"](MERGE|SELECT|UPDATE|DELETE|INSERT)\s[^;]*?/osi ;
my $regex2 = qr/.*\s\w{3,}\s+(\w{9,})\s*(?>\([^;={:|]*?\)[^()]*?{)/os;

#if ( Dawin::getstrdate() > '20160831' ) { print "** ��밡�ɱⰣ�� �������ϴ�. \n"; exit };

my %myopts = ();
my ( $wfile, @dir, $dirs, $sfile, $wsrc_dir, %fnHash, $exts, $g_std_time);

my $parm = "@ARGV" ;
getopts("achijkmnqstud:f:o:v:",\%myopts) or HELP_MESSAGE() ; 

if ( defined($myopts{h}) ) {
  HELP_MESSAGE();
  exit;
}  

if ( defined($myopts{d}) ) {
	@dir = map { glob }  split(/[, ]/,$myopts{d}) ;
	print "�˻� directory --> @dir\n";
} else { @dir = ('.') ; }

if ( defined($myopts{v}) ) {
	die "!! -v ������ ������ �����ϴ�.($myopts{v})" unless -e $myopts{v};
	$g_std_time = (stat($myopts{v}))[9] ;
	print "�����Ͻ�:[ ", Dawin::to_strdate($g_std_time,"-",":")," ]\n";
}

$dirs = join ('|',@dir) ;
if ( defined($myopts{o}) ) {
	$wfile = $myopts{o} ;
	if ( -f $wfile ) {
		my $choice ;
		print "*** $wfile �� ������?.(y/n) " ;
		chomp ($choice = <STDIN>);
		exit  if (lc($choice) ne "y")  ;
	}
}

my @Tlist = @ARGV ;

print "@Tlist","\n" if @Tlist ;

my ($fstr, %dbHash) ;
if ( defined($myopts{f}) ) {
	$sfile = $myopts{f} ;
  die "!! ������ ������ �����ϴ�.($sfile)" unless -e $sfile;
  if ( defined($myopts{k}) ) {
    read_funcName($sfile) ;
  } elsif ( defined($myopts{t}) ) {
    hash_const_2item($sfile) ;
  } else {
#  	local $/;
    open(my $fl,"<",$sfile) || die "$sfile $! \n";
    @Tlist = Dawin::trim(<$fl>) ;
    close($fl) ;
    hash_const();
  }
} else {
  if ( defined($myopts{t}) ) {
    while (@Tlist) {
      last if (scalar(@Tlist) < 2) ;
      $fstr = $Tlist[0]."\t".$Tlist[1] ;
   	  $dbHash{$fstr} = "1" ;
   	  splice(@Tlist,0,2);
   	}
  } else {
    hash_const();
  }
}
if ( defined($myopts{e}) ) {
	except_const($myopts{e}) ;
}

my $TOT_CNT  = 0 ;

Dawin::Log_start() ;

my ($FHW, $Fn1 ) ;

STDOUT->autoflush() ;
if ( defined($wfile) ) {
  print  "** ������� --> $wfile \n";
  open($FHW,">",$wfile) || die "$wfile $! \n";
  $FHW->autoflush() ;

#  $wsrc_dir = Cwd::abs_path(dirname($wfile)).'/src/' ;
#  make_path($wsrc_dir) ;
#  print "$wsrc_dir\n";
  
} else {$FHW = *STDOUT;}

if  ( defined($myopts{k}) ) {
	$Fn1 = \&inspect_func ;
	print $FHW " DIR \t ���ϸ� \t Function \t ȣ��DIR \t \ȣ�����α׷� \t �ٹ�ȣ \t �˻����� \n" ;
} elsif  ( defined($myopts{t}) ) {
	$Fn1 = \&inspect_file_2 ;
	print $FHW " TBL \t COL \t DIR \t ���ϸ� \t �ٹ�ȣ \t �˻����� \t DML \t �Լ��� \n" ;
} else {
	$Fn1 = \&inspect_file_new ;
	print $FHW " �˻��׸� \t DIR \t ���ϸ� \t �ٹ�ȣ \t �˻����� \t DML \t �Լ��� \n" ;
}

find($Fn1, @dir);

if ( defined($wfile) ) {
  close($FHW) ;
}
print  "\n** �۾����ϼ� ($TOT_CNT)\n" ;

Dawin::Log_end($parm,$TOT_CNT) ;

###################################
# �˻��׸� 1 New
###################################
sub inspect_file_new {
	return if ( ( -d || /\.(txt|log|exe|pdf)?$/i || /\d{8,}/ ) && ( ! defined($myopts{a}) ) );
	if ( defined($myopts{e}) ) {
		return if ( /$exts/ =~ /$_/ ) ;
	}
	if ( defined($myopts{v}) ) {
		return if ( (stat($_))[9] < $g_std_time) ;
	}	

	if( (-T or /\.(?:sql|pbl|sr.|pc|java|xml)?$/i) and !/\.(txt|log)?$/i) {
	$TOT_CNT++;
	Dawin::PRINT_1($TOT_CNT,$_) ; 
 	open (my $FF,"<",$_) or  print STDERR "** ERROR: $_ $!\n" and return ;
	my $cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	local $/;
	my ($winnm,  $line, $lsrc, $lscrud,$fnm,$item,$pos,$ln) = ('','','','','');
	$lsrc=<$FF> ;
	close $FF;
	my ($nstr,$cnt) ;

	if ( ! defined($myopts{c}) ) {
		while ($lsrc=~ m!(/\*.*?\*/)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$lsrc=~ s!!$nstr!s ;
		}
		while ($lsrc=~ m!(\soutlog\s*\(.*?\)\s*?;)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$lsrc=~ s!!$nstr!s ;
		}

		while ($lsrc=~ s!(?>//|--).*?$!!mg) {}
		while ($lsrc=~ m!(\#if\s+0[^#]*?\#else)!s) {
			$nstr = '';
			$cnt = ($1 =~ tr/\n//);
			$nstr = "\n"x$cnt if $cnt;
			$lsrc=~ s!!#if 1 $nstr!s ;
		}
		while ($lsrc=~ m!(\#if\s+1[^#]*?)(\#else\s[^#]*?\#endif)!s) {
			last unless $2 ;
			$nstr = '';
			$cnt = ($2 =~ tr/\n//);
			$nstr = "\n"x$cnt if $cnt;
			$lsrc=~ s!!$1 $nstr#endif!s ;
		}
		while ($lsrc=~ m!(\#if\s+0[^#]*?\#endif)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$lsrc=~ s!!$nstr!s ;
		}
		while ($lsrc=~ s!^[\t ]*\#[^#]*?$!!mg) {}

		while ($lsrc=~ m!(\sSPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$lsrc=~ s!!$nstr!s ;
		}
	}
	$lsrc =~ s!\\$!!mg ;
	
	$lsrc =~ /global type (\w+)\s+/ and $winnm = $1 ;
	while( defined($myopts{i}) ?  $lsrc =~ m!\W($fstr)\W!sigo : $lsrc =~ m!\W($fstr)\W!sgo ) {

		($item,$pos) = ($1,$-[1]) ;
		$line = substr($lsrc,$pos-12,130) ;
	  $line =~ /((?:\w+\.)?$item.+)[;}\n]/s and $line = $1;
		if (defined($myopts{w})) {
			next unless ($line =~ /\b(?:where|and)\b/i) ;
		}

		if ( substr($_,-3) eq 'pbl' ) {
  			next unless ($line =~ /(values|decode)/i) ;
  			next if (length($line) < 31) ;
  	}
		$line =~ s/\s/ /g;
		while ($line =~ s/  / /g){}
		$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
		$lscrud = "";
=begin comment		
		if ( substr($lsrc,0,$pos + 8) =~ /.*[;{]/s )
		{
			my $imsi = substr($lsrc,$+[0] - 4, $pos + 8) ;
			$imsi =~ /$regex1/ and $lscrud = uc($1);
		}
=cut		
		{ 	substr($lsrc,0,$pos) =~ /$regex1/ and $lscrud = uc($1); }
		if ( /c$/i ) 
		{ 	
			substr($lsrc,0,$pos) =~ /$regex2/ and $fnm = $1 ;
#			if ( my @tarr = (substr($lsrc,0,$pos) =~ /int\s+(\w+)\s*\([^;]*?\)\s*\{/sg) )
#				{ $fnm = $tarr[$#tarr]; }
		}

		$ln =  (substr($lsrc,0,$pos) =~ tr/\n//) ;
		$ln++ ;

		printf $FHW ("%s\t%s\t%s\t$ln\t%s\t%s\t%s\n",searchW( $item ) , $cdir, $_ , $line , $lscrud, $fnm ) ;

    } # while

    } # if end
}


sub inspect_file_2 {

	return if ( ( ! defined($myopts{a}) )  && ( -d $_ || /\.(txt|log|exe|pdf|swf|zip|wmv|jpg|gif|bmp|jar|class|bak|exml|lst|\d+)?$/i || /\d{8,}/) );
	if ( defined($myopts{e}) ) {
		return if ( /$exts/ =~ /$_/ ) ;
	}
	
	if ( defined($myopts{v}) ) {
		return if ( (stat($_))[9] < $g_std_time) ;
	}	
	$TOT_CNT++;
	print  "\r** �۾��� ($TOT_CNT): $_"," "x (60 - length($_)) ;

	if  ( /\.xml/i ) {
		inspect_xml() ;
		return ;
	}
	if  ( /\.pc/i ) {
		inspect_file_c() ;
		return ;
	}
	if( (-T && defined($myopts{a}) or /\.(?:java|jsp|sql)$/i) ) {

#	Dawin::PRINT_1($TOT_CNT,$_) ;
#	print  "\r** �۾��� ($TOT_CNT): $_"," "x (60 - length($_)) ;

  	open (my $FF,$_) or  print STDERR "** ERROR: $_ $!\n" and return ;
  	my ($cdir, $fcnt,$fchk, $ln,$pos, $line, $pos2, $s_ln ) ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	local $/;
  	my $ls=<$FF> ;
    close $FF ;
	my ($nstr,$cnt) ;
	if ( ! defined($myopts{c}) ) {
		while ($ls =~ m!(/\*.*?\*/)!s) {
			$nstr = '';
			$cnt = ($1 =~ tr/\n//);
			$nstr = "\n"x$cnt if $cnt;
			$ls =~ s!!$nstr!s ;
		}
	}
	
	foreach my $kk ( keys %dbHash ) {
		$pos2 = 0;
		$s_ln = 0;
		my ($tbl,$item)  = ( split /\s/,$kk ) ;
#			print STDERR "$tbl,$item \n";
		next if (length($tbl) < 2 || length($item) < 2) ;
		next unless ( $ls =~ /\b$item\b.*?\b$tbl\b|\b$tbl\b.*?\b$item\b/si ) ;
		$tbl =~ s/\$/\\\$/g ;
		$item =~ s/\$/\\\$/g ;
		$line = $ls ;
		my ($val,$lcnt,$rcnt) ;
		while ( $line =~ m!^[^/*].*[\.\s\"]($item|$tbl)[\.\s\"]!mi ) {
			$val = $1;
			last unless $-[1]  ;
			$pos2 += $-[1];
			$pos = $pos2;
			$pos += 3;
			$line = substr($line,$-[1]) ;
			my $lscrud = '';
			{ $line =~ /(SELECT|UPDATE|DELETE|INSERT)\s[^;]*?\Z/is and $lscrud = uc($1); }
#			print STDERR substr($line,0,60) ;
						
#			$pos2 += $-[0] if $line =~ /\n/ ;
			while ($line =~ m!.*(})!gs) {
				last unless $-[1]  ;
				$line = substr($line,0,$-[1] ) ;
				$lcnt = ($line =~ tr/{//);
				$rcnt = ($line =~ tr/}//);
				last if ( $lcnt  == $rcnt ) ;
			}
			if ( lc($val) eq lc($tbl)) {
				unless ($line =~ /^[^\/\*].*?[\.\s\"]($item)\b/mi) {
					$line = substr($ls,$pos2 ) ;
					next ;
				}
				$pos += $-[1];
			} else {
				unless ($line =~ /^[^\/\*].*?\s$tbl[\s@]/mi) {
					$line = substr($ls,$pos2 ) ;
					next ;
				}
			}

    		$ln = (substr($ls,0,$pos) =~ tr/\n//) ;
    		$ln++ ;
			$pos = $+[0] if ($+[0]) ;

    	$line = substr($ls,$pos,100) ;
			from_to($line ,"utf8", "euc-kr") if (defined($myopts{j}));
			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
  		$line =~ s/\s/ /g;
  		$line =~ s/^\s+|\s+$//;
  		$line =~ s/  / /g;
  		printf $FHW ("%s\t%s\t%s\t%d\t%s\t$lscrud\n", $kk ,$cdir, $_ ,$ln ,$line ) if ($s_ln != $ln);

  		$s_ln = $ln ;
			last if ( defined($myopts{s}) ) ;
  		$line = substr($ls,$pos2 ) ;
		} 
	}
	} # if end
}

sub inspect_file_c {
	# ��ü�� cud �˻��� ��ȸ������α׷� skip
	if ( defined( $myopts{u}) and /[RP]\.pc$/  ) {
		return ;
	}

	open (my $FF,$_) or  print STDERR "** ERROR: $_ $!\n" and return ;
	my ($cdir, $lstemp, $fcnt,$fchk, $ln,$pos1, $line, $pos2, $s_ln ) ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	$cdir = basename($File::Find::dir) if ($cdir eq '');
	local $/;
	my $ls=<$FF> ;
  close $FF ;
	my ($nstr,$cnt) ;

	if ( ! defined($myopts{c}) ) {
		while ($ls =~ m!(/\*.*?\*/)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$ls =~ s!!$nstr!s ;
		}
		while ($ls =~ m!(\soutlog\s*\(.*?\)\s*?;)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$ls =~ s!!$nstr!s ;
		}

		while ($ls =~ s!(?>//|--).*?$!!mg) {}
		while ($ls =~ m!(\#if\s+0[^#]*?\#else)!s) {
			$nstr = '';
			$cnt = ($1 =~ tr/\n//);
			$nstr = "\n"x$cnt if $cnt;
			$ls =~ s!!#if 1 $nstr!s ;
		}
		while ($ls =~ m!(\#if\s+1[^#]*?)(\#else\s[^#]*?\#endif)!s) {
			last unless $2 ;
			$nstr = '';
			$cnt = ($2 =~ tr/\n//);
			$nstr = "\n"x$cnt if $cnt;
			$ls =~ s!!$1 $nstr#endif!s ;
		}
		while ($ls =~ m!(\#if\s+0[^#]*?\#endif)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$ls =~ s!!$nstr!s ;
		}
		while ($ls =~ s!^[\t ]*\#[^#]*?$!!mg) {}
		
=begin comment
  c	Complement the SEARCHLIST.
  d	Delete found but unreplaced characters.
  s	Squash duplicate replaced characters.
  r	Return the modified string and leave the original string untouched.
=cut
		while ($ls =~ m!(\sSPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!s) {
			$nstr = $1;
			$nstr =~ tr/\n//csd;
			$ls =~ s!!$nstr!s ;
		}

	}
	$ls =~ s!\\$!!mg ;

	my $save_f = 0;
	$ls =~ /\s\w{3,}\s+\w+\s*\([^;={]*?\)\s*[^;]/s and $save_f = $-[0]   ;
	foreach my $kk ( keys %dbHash ) {
		$pos2 = $save_f;
		$s_ln = 0;
		my ($tbl,$item)  = ( split /\s/,$kk ) ;

		next unless ( substr($ls,$save_f) =~ /\b$item\b[^;]*?\b$tbl\b|\b$tbl\b[^;]*?\b$item\b/si ) ;

		next if (length($tbl) < 2 || length($item) < 2) ;
		$tbl =~ s/\$/\\\$/g ;
		$item =~ s/\$/\\\$/g ;
		$line = substr($ls,$save_f) ;
		my ($lscrud,$fnm,$val,@tarr) = ('','') ;
		while ( $line =~ m!.*?\W($item|$tbl)\W[^;]*?(;|union)!si ) {
			$val = $1;

			last unless $-[2] ;
			my $pp2 = $-[2] ;
			$pos1 = $pos2 ;
			$pos2 += $pp2 ;
			if ( uc($val) eq uc($tbl)) 
			{
				$line = substr($line,$-[1] - 1 ,$pp2 - $-[1] + 1 ) ;
				$pos1 += $-[1] ;			
			} else
			{
				substr($line,0,$-[1]) =~ /.*\n/s ;
				$line = substr($line,$+[0] ,$pp2 - $+[0] ) ;
				$pos1 += $+[0] ;
			}

			if ( ! defined($myopts{n}) && sql_tblcol($tbl,$item, $line ) == 0 ) {
				$line = substr($ls,$pos2 ) ;
				next ;
			}
				
			$lstemp = substr($ls,$save_f,$pos1 - $save_f) ;
			
			{ $lstemp =~ /$regex1/ and $lscrud = uc($1) ; }
			unless ($lscrud) { $line =~ /(MERGE|SELECT|UPDATE|DELETE|INSERT)/si and $lscrud = uc($1) ; }
#			while ($lstemp =~ s/EXEC\s+SQL\s[^;]*+?;//si) {}
			{ $lstemp =~ /$regex2/  and $fnm = $1 ;}
			
			if ( uc($val) eq uc($tbl)) {
				unless ($line =~ m!.*?\b($item)\b!si) {
					$line = substr($ls,$pos2 ) ;
					next ;
				}
				$pos1 += $-[1];
			} 
=begin comment	20160713 �����߰�		
			else {
				if ($lscrud =~ /INSERT|UPDATE/ ) {  # 8/20 �߰�
					$line = substr($ls,$pos2 ) ;
					next ;
				}
			}
=cut
			$lstemp = substr($ls,0,$pos1) ;

			$lstemp =~ /.*\n/s ;

			$ln = ($lstemp =~ tr/\n//) + 1;
			
#			$line = substr($ls,$+[0],140) ;
			substr($ls,$+[0],140) =~ /(.*)[\s;}]/s and $line = $1;
			from_to($line ,"utf8", "euc-kr") if (defined($myopts{j}));
			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
			$line =~ s/^[\s,]+|\s+$//s;
			$line =~ s/\s/ /g;
			while ($line =~ s/  / /g){}
			printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\t$fnm\n", $kk ,$cdir, $_ ,$ln ,$line, $lscrud ) if ($s_ln != $ln);
=begin comment    		
			if ( defined($wsrc_dir) ) {
				make_path($wsrc_dir.$cdir);
				copy($File::Find::name, $wsrc_dir.$cdir.'/'.$_) unless (-f $wsrc_dir.$cdir.'/'.$_ ) ;
			}
=cut			
  		$s_ln = $ln ;
			last if ( defined($myopts{s}) ) ;
  		$line = substr($ls,$pos2  ) ;
		} 
	}

}

sub inspect_xml {
	return unless (/\.xml/i) ;

	my (@sResult, $QID, $cdir, $ls, $fchk, $fcnt, $pos ) ;

  	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
  	while( my $line=<$FF>) {
  		@sResult = ($line =~ /<(?:(?:query|select|update|delete|insert) id|statement name)="?(.+?)["\s>]{1}/i );
  		if (@sResult) {
  			$QID = $sResult[0] if $sResult[0] ;
  			$QID =~ s/\"$// ;
  			next ;
  		}
  		next unless $QID ;
  		$ls = '';
		until ($line =~ m!</(?:query|select|update|delete|insert|statement)>!i  or eof($FF) ) {
  			$ls .= $line ;
  			$line=<$FF> ;
		}
		foreach my $kk ( keys %dbHash ) {
			$fcnt = 0;
			$fchk = 0;
			undef $pos ;
			foreach my $item ( split /\t/,$kk ) {
				$fcnt++ ;
  				if ($ls =~ /\W$item\W/s) {
  					$fchk++ ; 
  					$pos = $-[0] if ( !defined($pos) or $pos > $-[0]); 
  				} 
			}
			
			if ($fcnt > 0 and $fcnt == $fchk) {
  				$line = substr($ls,$pos,100) ;
				from_to($line ,"utf8", "euc-kr") if (defined($myopts{j}));
				$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
  				$line =~ s!^\s+|\s+$!! ;

  				$line =~ s/\s/ /g;
    			$line =~ s/  / /g;
				my $lscrud = '';
				{ $ls =~ /\b(SELECT|UPDATE|DELETE|INSERT)\b/i and $lscrud = uc($1); }

				printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\n", $kk ,$cdir, $_ ,$. ,$line,$lscrud ) ;
			}
		}
		undef $QID;
    }
    close ($FF) ;
}
# �������ϸ�� 
sub except_const {
    my $sfile = shift;
	if (-e $sfile) {
		open (my $FF,"<",$sfile) or  print STDERR "** ERROR: $sfile $!\n" and return ;
		local $/;
		$exts = <$FF>;
	} else {
		$exts = $sfile ; # =~ s/\./\\./gr ;
	}
}

sub searchW {
	my ($item,$tg) ;
	$tg = shift ;
	return " " unless $tg ;
	foreach $item (@Tlist) {
		$item =~ s/\$/\\\$/sg ;
		return $item if $tg =~ /$item/si ;
	}
	return $tg ;
}
sub hash_const {

    chomp(@Tlist);
    
    @Tlist = sort {length($b) <=> length($a)} @Tlist ;
	if (defined($myopts{m}) ) {
		$fstr = join ("|",map { SELECT_ALL.$_.'|'.$_.INSERT_ALL.'|INSERT\s+INTO\s+'.$_.'\s+\(?\s+SELECT' } @Tlist ) ;
	} elsif (defined($myopts{q})) {
		$fstr = join ("|",map { SELECT_ALLJ.$_.'|'.$_.INSERT_ALL } @Tlist ) ;
	} else {
	    $fstr = join ("|",map { length($_) <= 2 ? '\b(?:[gs]et)*'.$_.'\b' : $_ } @Tlist ) ;
	}
    $fstr =~ s/\$/\\\$/g ;
}

sub hash_const_2item {
    my $sfile = shift;
    my @items ;
    open(my $sfh,"<", $sfile) || die "$sfile $! \n";
    while(<$sfh>)
    {
    	next if (/DIR.+�˻�����/) ;
      chomp;
      @items = split(/\s+/, $_);
      @items = Dawin::trim(@items);
		  next if (scalar(@items) < 2) ;
    	$dbHash{$items[0]."\t".$items[1]} = "1" ;
    }
    
    close($sfh);
#    my (@lstA, @lstB) ;
#    for my $kk (keys %dbHash) {
#    	push(@lstA, $dbHash{$kk}->[0]);
#    	push(@lstB, $dbHash{$kk}->[1]);
#    }

}

sub read_funcName {
    my $sfile = shift;

    open(my $INF,"<",$sfile) or die "$! \n";
	$fstr = '';
	<$INF> ;
	
  print "read_funcName: ", $sfile,"\n" ;
	my ($ldir,$pgid,$fname,$dname) ;
    while (<$INF>)
    {
      chomp;
      if ( defined($myopts{t}) ) 
      {
      	($ldir,$pgid,$fname) = (split(/\t/, $_))[2,3,7]  or (split(/\t/, $_))[1,2,6]  or next;
      }
      else
      {
      	($ldir,$pgid,$fname) = (split(/\t/, $_))[1,2,6]  or next;
      }
			next unless ($fname) ;
			next unless ($pgid) ;
			$dname = $ldir."\t".$pgid ;
			$fnHash{$fname} = $dname ;
    }
	$fstr = join ("|",keys %fnHash) ;
    print  "read_funcName e: ", scalar(keys %fnHash ),"\n" ;
    close ($INF);
	

}

sub inspect_func {
	return unless (/\.(?:pc|java)/i) ;
	$TOT_CNT++;
	Dawin::PRINT_1($TOT_CNT,$_) ; 

	my ( $src,$cdir,$item,$pos, $ln,$line,$ldir,$pgid ) ;
	local $/;
	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	$src = <$FF>;
	close $FF;
	my ($nstr,$cnt) ;
	while ($src =~ m!(/\*.*?\*/)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!/\*.*?\*/!$nstr!s ;
	}
	while ($src =~ m!(^\s*outlog\s*\(.*?\)\s*;)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!^\s*outlog\s*\(.*?\)\s*;!$nstr!s ;
	}
	while ($src =~ m!(^\s*SPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!^\s*SPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;!$nstr!s ;
	}

  	while ($src =~ /\b($fstr)\b/g) {

		($item,$pos) = ($1,$-[1]);
		($ldir,$pgid)  = ( split /\t/,$fnHash{$item} ) or die "$! \n";
		next if ($pgid eq $_);

		$ln = ( substr($src,0,$pos) =~ tr/\n//) ;
		$ln++ ;
		$line = substr($src,$pos-5,100) ;
		$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
		$line =~ s!^\s+|\s+$!! ;

		$line =~ s/\s/ /g;
		$line =~ s/  / /g;
		print $FHW ("$ldir\t$pgid\t$item\t$cdir\t$_\t$ln\t$line\n" )  ;
    }

}

sub search_func_call {
	return unless (/\.(?:pc|java)/i) ;
	$TOT_CNT++;
	Dawin::PRINT_1($TOT_CNT,$_) ; 
	my ($pgid) = split('\.',$_) ;
	my ( $src,$src1,$cdir,$item,$pos, $ln,$line,$ldir ) ;
	local $/;
	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$cdir = $File::Find::dir;
	$cdir =~ s!^(?:$dirs)/?!! ;
	$cdir =~ s!^\.{1,2}/?!! ;
	$src = <$FF>;
	close $FF;
	my ($nstr,$cnt) ;
	while ($src =~ m!(/\*.*?\*/)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!/\*.*?\*/!$nstr!s ;
	}
	while ($src =~ m!(\#if 0.*?\#endif)!s) {
		$nstr = '';
		$cnt = ($1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!\#if 0.*?\#endif!$nstr!s ;
	}
	while ($src =~ m!(^\s*outlog\s*\(.*?\)\s*;)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!^\s*outlog\s*\(.*?\)\s*;!$nstr!s ;
	}
	while ($src =~ m!(^\s*SPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;)!s) {
		$nstr = '';
		$cnt = ( $1 =~ tr/\n//);
		$nstr = "\n"x$cnt if $cnt;
		$src =~ s!^\s*SPRINTF\s*\(\s*gsErrMsg\b.*?\)\s*;!$nstr!s ;
	}
	$src =~ /\s(main|$pgid)\s*\(.*?\)\s*{/ ;
	$src1 = substr($src,0, $+[0]);
	$src  = substr($src, $+[0]);
  while ($src =~ /(w{8,})\s*\(.*?\)\s*[^{]/sg) {

		($item,$pos) = ($1,$-[1]);

		$ln = ( substr($src,0,$pos) =~ tr/\n//) ;
		$ln++ ;
		print $FHW ("$ldir\t$_\t$item\t$ln\n" )  ;
	}

}

sub sql_tblcol {
	my ($tbl,$col,$pstr) = @_ ;
	my ($lstr, $alias) ;
	$pstr = ' '.$pstr;
	while ($pstr =~ s/--.*$//mg) {}
	while ($pstr =~ s/''\s+\w+| as\s+\w+/ /si) {}
	while ($pstr =~ s/\'(?:$col|$tbl)\'/ /sg) {}
	
	while ($pstr =~ /\(([^()]{3,}?)\)/s) {
		$lstr = $1 ;
		$alias = "" ;
		$lstr =~ /\b$tbl\s+(\w{1,2})\W/si and $alias = $1.'.' ;

		return 1 if ($lstr =~ /[^\w.](?:$alias|$tbl\.)?$col\b.*$tbl\b|\b$tbl\s.*[^\w.](?:$alias|$tbl\.)?$col\b/si)  ;
		if ($lstr =~ /\s*SELECT\s.*\sFROM/si)
		{
			$pstr =~ s/\(([^()]*?)\)/ /s ;
		} else
		{
			$pstr =~ s/\(([^()]*?)\)/ $1 /s ;
		}
	}
	$alias = "" ;
	$pstr =~ /\b$tbl\s+(\w{1,2})\W/si and $alias = $1.'.' ;
	return 1 if ($pstr =~ /[^\w.](?:$alias|$tbl\.)?$col\b.*$tbl\b|\b$tbl\s.*[^\w.](?:$alias|$tbl\.)?$col\b/si)  ;
	return 0 ;
}

sub HELP_MESSAGE{
  die <<'END';

�˻��׸��� ���� ���α׷��� ã�´�.
Usage: $0 [-acijkmnst][-o �������][-d �˻�DIR] [-v �������� ] ([-f �˻��׸�����] | -e �˻��� ) 

 -a : ��������� �˻�������� ��
 -c : �ּ����԰˻�
 -d : �˻�DIR ( ������ ���� ���丮 �˻� )
 -t : ���̺�,Į�� 2�׸����� �˻�(������ 1�׸�˻�)
 -i : ��ҹ��� ����
 -j : utf8 => euc-kr ��ȯ
 -k : �˻������ �Լ��� ����ϴ� ���� �˻� -kt, -k
 -m : SELECT * INSERT * �˻�
 -q : SELECT * INSERT * �˻�(java,xml)
 -s : �ּҰ˻� ( ���ϳ����� 1ȸ�� ǥ�� )
 -f �˻����� : �˻����� ��ϵ� �ؽ�Ʈ ����
 -o ������� : ������ ���Ϸ� �˻���� ���� ����. 
 -v �������� : �������� ���� ����� ���� ���� 
 �˻��׸����� : ������ �˻��׸��� ���κ��� �и�
   ��)
     �˻��׸�1
     �˻��׸�2
     .
     .
     �˻��׸�n

   * -t �ɼ��� �־��� ���� Į���� ���̺������� �����Ѵ�.
     ���̺���1 Į���׸�1 
     ���̺���2 Į���׸�2 
     .
     .    
     ���̺���n Į���׸�n 

�˻�DIR�� ������ ����DIR���� �˻�������.

END
}