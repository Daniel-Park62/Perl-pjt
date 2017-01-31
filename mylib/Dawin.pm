package Dawin;

use File::Basename;

my %ExtHash ;
my $Gfmt = ($^O =~ /mswin/i ? "\r%-80.80s" : "\033[1A\033[K%s\n" ) ;

my ($Gst_time, $Ged_time, $Gst_dt, $Ged_dt);
our $Glogfile;

our $Gexp_list = <<END;
add append
debug decode
getstring getConnection getproperty setproperty setstring get set
invoke isnull if my for while until isempty isnumber open this equals  
memset memcpy min
nvl
println print put
strcpy strcmp strlen substringn sum
trim rtrim ltrim trace
END

sub Log_start {
	$Gst_time = time ;
	$Gst_dt   = localtime ;
	my $cfile = (caller(0))[1];
	my $yy = substr(to_strdate($Gst_time),0,4) ;
	$Glogfile = dirname($0)."/dawinlog_$yy.log" ;
	if ( $cfile !~ /dawinfind/i ) { $Glogfile = dirname($0)."/dawinlog2_$yy.log" ;}
	print "\n*** Start $0 : $Gst_dt \n";
	print   "*** 로그파일 : $Glogfile \n";
}

sub Log_end {
	my ($parm, $tot_cnt) = @_ ;
	open(my $FLOG,">>",$Glogfile) || die "$! \n";
	$Ged_dt = localtime ;
	$Ged_time = time;
	my $diff = $Ged_time - $Gst_time ;
	
	printf ("\n***   End $0 : $Ged_dt ## 소요시간 : %d시간 %d분 %d초\n",$diff/3600, int $diff%3600/60, $diff%60) ;
	print  $FLOG   ("\n*** Start $0 : $Gst_dt") ;
	print  $FLOG   ("\n 실행옵션( $parm ) 작업위치 ",Cwd::abs_path("."));
	print  $FLOG   ("\n 작업파일수 ($tot_cnt)") if $tot_cnt ;
	printf $FLOG   ("\n***   End $0 : $Ged_dt : ## 소요시간 : %d시간 %d분 %d초\n", $diff/3600, int $diff%3600/60, $diff%60) ;
	close($FLOG);
	
}

sub trim {
	my ($item, @result, %temp);
	foreach $item (@_) {
		$item =~ s/^\s+|\s+$//;
		next unless length($item)  ;
		push(@result,$item) unless  $temp{$item}++ ;
	}
	return wantarray ? @result : $result[0] ;
}

sub comma {
	my $vals = $_[0] ;
	while ( $vals =~ s/(^[+-]?\d+)(\d{3})/$1,$2/ ) { };
	return $vals ;
}

sub ExtCount {
	my ($Act,$Ext) = @_ ;
	if ($Act eq 'print') {
		print  "\n*-----<< 종류별 파일수 >>------*\n" ;
		my $tot ;
		for my $aa  ( sort keys %ExtHash ) {
			printf  "%10s => %5d \n",length($aa) ? $aa : '확장자없음' , $ExtHash{$aa} ;
			$tot += $ExtHash{$aa} ;
		}
		printf  "\n%10s => %5d \n", '** Total',$tot ;
		print  "*-----<<     E N D     >>------*\n" ;
	} elsif ($Act eq 'init') {
		%ExtHash = () ;
	} else {
		$Ext =~ s/.*\.//  or $Ext = '' ;
		$ExtHash{$Ext}++ ;
	}
}

sub PRINT_1($$) {
	my ($CNT, $FNM) = @_ ; 
	printf ($Gfmt,"* Scanning.. ($CNT):". substr($FNM,-65)) ; 
	return "";
}
sub PRINT_2($$$) { 
	my ($CNT, $FNM, $FH) = @_ ;
	printf ($Gfmt,"* Scanning.. ($CNT): $FNM") ; 
}

sub PRINT_Log($$;) {
	my ($NY,$FNM) = @_ ;
	open my $FLOG,">>",$FNM  or print STDERR "$FNM $! \n" ;
	my $ltm = localtime ;

	print $FLOG  "\n*** $ltm ***\n[$NY]\n**************\n" ;
	close $FLOG;
}

#   0    1    2     3     4    5     6     7     8
#  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
#  아규먼트 : 일시,날짜구분자,시간구분자
sub to_strdate {
  my ($pdate,$deli,$dl2) = (@_ , '','') ;
  my ($ss,$mi,$hh,$dd,$mm,$yy) = (localtime($pdate))[0..5] ;
  sprintf "%d$deli%02d$deli%02d %d$dl2%02d$dl2%02d", $yy+1900, $mm+1, $dd, $hh,$mi,$ss;
}

sub getstrdate {
  my ($deli) = (@_ , '') ;
	return substr(to_strdate(time, $deli),0,8) ;
}

sub is_dir {                                 # {{{1
    # portable method to test if item is a directory
    # (-d doesn't work in ActiveState Perl on Windows)
    my ($item) = @_;
	
    if (($^O =~ /^MSWin/) or ($^O eq "Windows_NT"))  {
        my $mode = (stat "$item")[2];
           $mode = 0 unless $mode;
           print "$item,$mode,\n";
        if ($mode & 0040000) { return 1; } 
        else                 { return 0; }
    } else {
        return (-d $item);  # works on Unix, Linux, CygWin, z/OS
    }
} # 1}}}

sub sort_file {
  my $sheet;
  my $count = -1;
  
  while( <DATA> ) {
    chomp;
    $count++;
    # skip header
    next unless $count;
    my $row;
    @$row = split( /,/, $_ );
    push @$sheet, $row;
  }
  
  foreach my $row ( sort { $a->[1] <=> $b->[1] } @$sheet ) {
    print join( ',', @$row ), "\n";
  }

}

sub func_argfind {
	my (@sResult ,$imsi, $i,$fnm, $spos, $line, $fstr, $tHashRef) ;
	$line = shift ;
	$fstr = shift ;
	$tHashRef = shift ;
	$line =~ s/\".*?\"/xxxxxxxxxxxx/g ;
	if  ($line =~ /.*\b(\w+\s*\(.*?\)).*/ )  {
		if ($-[1]) {
			func_argfind($1,$fstr,$tHashRef) ;
			$line =~ s/(.*\b)(\w+\s*\(.*?\))(.*)/$1xyxyxyxy$3/ ;
		}
	}
	if ($line =~ /$fstr/) {
		return unless $line =~ /.*\b(\w+?)\s*\(/ ;
		$fnm = $1 ;
		$spos = $-[1] ;
		return if $Dawin::Gexp_list =~/\b$fnm\b/i ;
		@sResult = ();
		@sResult = ( substr($line,$spos) =~ /.*?\b(\w+)\b[,\)]/g ) ;
		return if $#sResult == -1 ;
		for $i ( 0..$#sResult){
			if ($sResult[$i] eq $fstr) {
				$tHashRef->{$fnm}->{$fstr} = $i ;
				last ;
			}
		}
	}
}

# parameter \@ 
sub select_menu
{
    my $tmpRefArray = shift;
    my @m = @{$tmpRefArray};
    chomp(@m);
    my $choice;
    while (1)
    {
      # Comment out this line if you don't want a title.
      # Otherwise the first element in the array must be the title.
      system($^O =~ /MS/ ? "cls":"clear") ;
		  print "\n $m[0]\n\n" ;
      print map { "\t$_. $m[$_]\n" } (1..$#m);
      print "\n\tQ. 종료\n" ;
      print "\n 번호를 선택하세요. (1-$#m)> ";
      chomp ($choice = <STDIN>);
      last if ( ($choice > 0) && ($choice <= $#m ) || lc($choice) eq 'q'  ) ;
      print "올바른 번호를 선택하세요.\n\n";

    }
    return $choice ;
}

sub select_dir {
	my ($sdir, $nm) = (@_,'') ;
	while (1) {
		print " $nm 디렉토리를 선택하세요.(기본값:현재디렉토리) > " ;
		chomp ($sdir = <STDIN>) ;
		$sdir = '.' unless $sdir;
		$sdir =~ s!\\!/!g;
		last if -d $sdir;
		print "!! $nm 디렉토리를 바르게 지정하세요.( $sdir )\n" ; 
	}
	return $sdir ;
}

1;
__DATA__