# 2.0
package Dawin_cont ;
use warnings;
use strict;
use File::Find;
use File::Basename;
use Dawin;
#use FinderDB qw (insert_file_to_db);
#use Data::Dumper qw(Dumper);

my ($FHW, $wfile, $sfile,$dir,$odir, $logfile, $RULE, $extList);

my (%mHash, %dbHash,%tHash, %ActionJsp, @fList,$cur_name,$Vars, $fstr, $oz_fstr,$SW,  $TOT_CNT, $ORG_dir, $Loop, $start);

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
        my $end = time;
        my $diff = $end - $start;
        die "\n소요시간 : $diff 초. Aborting.\n";
} ;

sub find_run {
	(%mHash, %dbHash,%tHash, %ActionJsp) = () ;
#   입력파일,검색dir,출력dir,log파일,실행규칙구분,제외파일목록ref
	($sfile,$dir,$odir,$logfile, $RULE, $extList) = @_ ;
	if (! -d $odir) {
		print "결과를 저장할 path($odir)을 확인하세요"  ;
		return 9 ;
	}
	
	die "!! $sfile 를 찾을수 없습니다." unless -e $sfile;
	#die "!! text파일을 지정하세요" unless -T $sfile;
	
	die "!! 검색DIR을 바르게 지정하세요" unless -d $dir;
	$ORG_dir = Cwd::abs_path($dir) ;
	
	$fstr = basename($sfile) ;
	$fstr =~ s/qi0_|r2_/tmp_/i  ;

	$start = time;
	
	in_actionjsp($odir.'/'.$fstr) ;

#	$wfile = basename($sfile) ;
#	$wfile =~ s!^\.{1,2}/?!! ;
	$wfile = $sfile ;
	my ($Fn1, $Fn2, $Fn3) ;
	if ($RULE == 2) {
	  	$wfile = $odir.'/r2_'.basename($sfile) ;
	  	$Fn1 = \&hash_const_r2 ;
	  	$Fn2 = \&file_analyzer_r2 ;
	  	$Fn3 = \&fstr_conj_r2 ;
	} elsif ($RULE == 3 || $RULE == 4) {
	  	$Fn1 = \&hash_const_r3 ;
	  	$Fn2 = \&print_if_file ;
	  	$Fn3 = \&fstr_conj_r3 ;
#	    $wfile =~ s!qi0!/qi1!i ;
	} else {
	  	$Fn1 = \&hash_const ;
	  	$Fn2 = \&print_if_file ;
	  	$Fn3 = \&fstr_conj ;
#	    $wfile =~ s!qi0!/qi1!i ;
	}
	
	print  "\n** 검색DIR  --> ",$ORG_dir,"\n" ;
	print  "** 입력파일 --> $sfile \n";
	print  "** 로그파일 --> $logfile \n";
	print  "** 결과파일($RULE) --> $wfile \n";

	%dbHash = ();
	
	$Fn1->($sfile) ;
	  
	my $sltm = localtime ;
	print  "\n*** Start v1.0 $0 : $sltm \n";
	open($FHW,">>",$wfile) || die "$! \n";

=begin commect
	if ($RULE > 1) {
		print $FHW " TBL \t Column \t Directory \t 프로그램ID \t line \t 검색내용 \t Class \t 연관검색값 \t seq \n" ;
	} else {
		print $FHW " 검색항목 \t Directory \t 프로그램ID \t line \t 검색내용 \t Class \n" ;
	}
=cut
	if ($RULE == 2) {
		print $FHW " TBL \t Column \t Directory \t 프로그램ID \t line \t 검색내용 \t Class \t 연관검색값 \t seq \n" ;
	}
	%mHash = %dbHash ;
	
	for ($Loop =1; $Loop < 16 ; $Loop++)  { 
	    chdir $ORG_dir  ;
	    $dir = '.' ;
	  	$TOT_CNT = 0 ; 
	  	$SW = 0 ;
	  	%tHash = (); 
	  	$Fn3->() ;
	  	print "\n\n** $Loop 차 **\n";
	  	find($Fn2, $dir);
	  	last unless $SW;
	  	last unless scalar(keys %tHash) ;
	  	%dbHash = %tHash ;
	} 
	
	print "\n** 작업파일수 ($TOT_CNT)\n" ;
	
	close($FHW) ;
	  
	my $eltm= localtime;
	my $end = time;
	my $diff = $end - $start;
	    
	open(FLOG,">>",$logfile) || die "$! \n";
	printf  ("\n***   End $0 : $eltm  ## 소요시간 : %d시간 %d분 %d초 .\n",$diff/3600, int $diff%3600/60, $diff%60) ;
	printf FLOG   ("\n*** Start $0 : $sltm \n***   End $0 : $eltm : $sfile ($RULE) ## 소요시간 : %d시간 %d분 %d초 .\n",$diff/3600, int $diff%3600/60, $diff%60) ;
	close(FLOG);

#	insert_file_to_db('SYS',$wfile) ; 
}

sub print_if_file {
	return if ( -d $_ ) ;
	return unless ( /\.(java|jsp|oza)$/i) ;
	if ( defined($$extList) ) { return if (/$$extList/ ); }
	$TOT_CNT++ ;
	my ($imsi, $CLSnm, $spos, $line, $DTcls,$tmp,$tmpM, $imple, $method, $cmdid, $Filepos, $ss, $crud) ;
	$cur_name = $_ ;
	Dawin::PRINT_1($TOT_CNT,$_) ;

	if (/\.oza$/i) {
		file_oza_proc() ;
		return ;
	}
	open (my $FF , "<", $_) or  print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;
	$dir = $File::Find::dir;
	$dir =~ s!^\.{1,2}/?!! ;

  while( $line=<$FF>) {
  	next if ($line =~ m!^\s*(?:\*|//|/\*|package|import)!) ;
		$line =~ s/^\s+//;
		chomp($line);
		undef $imsi ;
		if ($line =~ /^\s*public\s+class\s+(\w+)\b/) {
			$CLSnm = $1 if ($1) ;
  		if ($line =~ /^\s*public\s+class\s.*\bimplements\s+(\w+)\b/) {
				$tmp = $1 ;
				$imple = $tmp if (! $imple && $tmp =~ /Ctl$/) ;
			}
 			next ;
		}
#		undef $method if ( $line =~ /^\s*(?:public|protected)\s*\b.+\s*\b\w+\(/ ) ;
		if ( $line =~ /^\s*(?:public|private|protected)\s+[^({=]*?\s+(\w+)\s*\(/ ) { $method = $1 ; next ;}
		undef $cmdid if ( $line =~ /^\s*(?:public|private|protected)\s*\b.+\s*\b\w+\(/ ) ;
# 이동 0319
		$tmp = substr($CLSnm,0,-4) if ($CLSnm and uc(substr($CLSnm,-3)) eq 'DAO' and ! $DTcls);
		if ($tmp) {
			if ($line =~ m!^\s*public\s*($tmp\w+)\s!) {
				$tmp = $1 ;
				$DTcls = $tmp if ( uc(substr($tmp,-3)) ne 'DAO' and $tmp =~ /(?:View|dto|vo|to)$/i);
    		}
		}
		next if (substr($_,-4) eq 'java' && ! $CLSnm) ;
		next unless ( $line =~ /\W($fstr)\W/ ) ;
		$imsi = $1;
#		print  "1.$1,$CLSnm,$method\n" if ($1 =~ /retrieveUdwDetlList/) ;
		$imsi =~ s/\"//g ;
		unless ( $dbHash{$imsi} ) {
			$imsi = $ActionJsp{$imsi} if ($ActionJsp{$imsi});
			unless ( $dbHash{$imsi} ) {
				$dbHash{$imsi} = $mHash{$imsi} if ($mHash{$imsi} ) ;
			}
		}

  		next unless $imsi ;
  		next unless $dbHash{$imsi} ;

		$CLSnm = '' unless $CLSnm ;
  		last if ( substr($_,-4) eq 'java' && $CLSnm eq $imsi )  ;

		$spos = $. ;
		undef $ss ;
		if (substr($_,-3) eq 'jsp' && defined($dbHash{$imsi}->{cmdid})  ) {
			$tmp = $dbHash{$imsi}->{cmdid} ;
			($ss) = ($line =~ /cmd\b.*\b($tmp)\b/ig) ;
			unless ($ss) {
    			$Filepos = tell($FF);
    			my $s_pos = $. ;
    			while ( my $line=<$FF> ) {
					next if ($line =~ m!^\s*(?:\*|//|/\*|package|import|public)!) ;
					next if ($line =~ m!^\s*(?://|/\*)!) ;
    				$spos = $. ;
					$line =~ s!//.*$!! ;
    				($ss) = ($line =~ /\b($tmp)\b/) ;
    				last if ($ss) ;
    			}
				seek($FF,$Filepos,0) ;
    			$. = $s_pos ;
    			next unless ($ss) ;
    		}
		} 

		$line =~ s/\s\s/ /g;
		$line =~ s/^\s+|\s+$//;
		$line =~ s/[\t\r\n]/ /g;

		if (length($line) > 100 ) {
			$line = substr($line,0,100 ) ;
			$line =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/ if ($line =~ /[\x80-\xff]/ ) ;
		}

		$tmp = $imsi;
		if ( $Loop > 1 && $dbHash{$imsi}->{parent} && ($tmp =~ /(?:Ctl|View|dto|vo|to)$/i) ) 
		   { $tmp = $dbHash{$imsi}->{parent} ; }
		if ($dbHash{$imsi}->{cnt}) {
			if (length($CLSnm) > 0 and !defined($mHash{$CLSnm}) ) {
				my %xx ;
				hash_copy(\%xx,$dbHash{$imsi} ) ;
				$tHash{$CLSnm} = \%xx ; 
				$tHash{$CLSnm}->{method} = {} ;
				$mHash{$CLSnm} = $tHash{$CLSnm} ; 
			}
			foreach my $i ( 1..$dbHash{$imsi}->{cnt} ) {
				$crud = $dbHash{$imsi}->{$dbHash{$imsi}->{$i}} || '';
#				printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\t%s\t$Loop\t%s\n", $dbHash{$imsi}->{$i} ,$dir, $_ , $spos , $line, $CLSnm,  $tmp, ($tmp ne $imsi) ? $imsi : '') ;
				printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\t%s\t$Loop\t%s\n", $dbHash{$imsi}->{$i} ,$dir, $_ , $spos , $line, $CLSnm,  $tmp, $crud) ;
				$SW = 1;
				if ($tHash{$CLSnm} && $method && $CLSnm ne $method ) {
					$tHash{$CLSnm}->{method}->{$method."\t".$dbHash{$imsi}->{$i}} = $crud;
					delete $tHash{$CLSnm}->{$i} ;
				}
			} 
			delete $tHash{$CLSnm}->{cnt} if ($method && $CLSnm ne $method ) ;
		}

		($cmdid) = join '|',$line =~ /cmd\.equals\(\"([^"]+?)\"\)/ig  if ( $line =~ /cmd\.equals\(\"[^"]+?\"\)/i ) ;
		($cmdid) = join '|',$line =~ /\(\"([^"]+?)\"\.equals\(cmd/ig  if ( $line =~ /\(\"[^"]+?\"\.equals\(cmd/i ) ;

		$Filepos = tell($FF) ;
		my $sv_method = $method ;
		my $s_pos = $. ;
		if ($dbHash{$imsi}->{method}) {
			foreach my $hkey (keys %{$dbHash{$imsi}->{method}} )  {
				my ($mt,$tbl,$col) = split(/\t/, $hkey) ;
				$method = $sv_method ;
				while ( $line=<$FF> ) {
					if ( $line =~ /^\s*(?:public|private|protected)\s[^({=]*?\s(\w+)\s*\(/ ) { $method = $1; next; }
					$spos = $. ;
					next if ($line =~ m!^\s*(?:\*|//|/\*|package|import|public)!) ;
					$line =~ s!(.*)//!$1! ;
					($ss) = $line =~ /\W($mt)\W/ ;
					last if ($ss) ;
				}
				seek($FF,$Filepos,0) ;
				$. = $s_pos ;
				next unless ($ss)  ;
				if (length($CLSnm) > 0 and !defined($mHash{$CLSnm}) ) {
					my %xx ;
					hash_copy(\%xx,$dbHash{$imsi} ) ;
					$tHash{$CLSnm} = \%xx ; 
					$tHash{$CLSnm}->{method} = {} ;
					$mHash{$CLSnm} = $tHash{$CLSnm} ; 
				}
				$tmp = $imsi;
				if ( $Loop > 1 && $dbHash{$imsi}->{parent} && ($tmp =~ /(?:Ctl|View|dto|vo|to)$/i) ) 
				   { $tmp = $dbHash{$imsi}->{parent} ; }

				$line =~ s/\s\s/ /g;
				$line =~ s/^\s+|\s+$//;
				$line =~ s/[\t\r\n]/ /g;
				$crud = $dbHash{$tmp}->{method}->{$hkey} || '';
#				printf $FHW ("$tbl\t$col\t%s\t%s\t%d\t%s\t%s\t%s\t$Loop\t%s\t$ss\n", $dir, $_ , $spos , $line, $CLSnm,  $tmp, ($tmp ne $imsi) ? $imsi : '') ;
				printf $FHW ("$tbl\t$col\t%s\t%s\t%d\t%s\t%s\t%s\t$Loop\t%s\t$ss\t$method\n", $dir, $_ , $spos , $line, $CLSnm,  $tmp, $crud) ;
				$SW = 1;
				if (defined($tHash{$CLSnm}) ) {
					if ($method && $CLSnm ne $method ) {
						$tHash{$CLSnm}->{method}->{$method."\t".$tbl."\t".$col} = $crud;
					}
				}
			} # end foreach my $hkey (keys $dbHash{$imsi}->{method} ) 
		}
		
		if  ( $dbHash{$imsi}->{cnt} ) {
			if ( length($CLSnm) > 0) {
				unless( $mHash{$CLSnm})  {
					if ($cmdid && $tHash{$CLSnm}->{cmdid} ) {
						$tHash{$CLSnm}->{cmdid}.='|'.$cmdid unless ( $tHash{$CLSnm}->{cmdid} =~ /$cmdid/ ) ;
					} elsif ($cmdid) {
						$tHash{$CLSnm}->{cmdid} = $cmdid ;
					}
					$mHash{$CLSnm} = $tHash{$CLSnm}; 
				}
			}

			if ($DTcls and substr($_,-4) eq 'java') {
				unless ( $mHash{$DTcls}) { 
					my %xx ;
					hash_copy(\%xx,$dbHash{$imsi} ) ;
					$tHash{$DTcls} = \%xx ; 
					$tHash{$DTcls}->{parent} = $CLSnm ;
					$tHash{$DTcls}->{method} = {} ;
					delete $tHash{$DTcls}->{cmdid} ;
					$mHash{$DTcls} = $tHash{$DTcls} ; 
				}
			}

			if ($imple and substr($_,-4) eq 'java') {
				unless ( $dbHash{$imple}) {
					my %xx ;
					hash_copy(\%xx,$dbHash{$imsi} ) ;
					$tHash{$imple} = \%xx ; 
					$tHash{$imple}->{parent} = $CLSnm ;
					$tHash{$imple}->{method} = {} ;
					delete $tHash{$imple}->{cmdid} ;
					$mHash{$imple} = $tHash{$imple}  ;
				}
			}
		}
    }
    close $FF ;
}

sub hash_copy {
	my($bb, $aa) = @_ ;
	foreach my $kk (keys %{$aa} ) {
		$bb->{$kk} = $aa->{$kk} ;
	}
}

sub file_oza_proc {
		my $pgid = substr($_,0,-4) ;
		return if ($ActionJsp{$pgid}) ;
    	open (my $FF,$_) or  print STDERR "\n** ERROR: $_ $!\n" and return ;
		my $cdir = $File::Find::dir;
		$cdir =~ s!^$dir/?!! ;
		$cdir =~ s!^\.{1,2}/?!! ;

		my ($imsi,$sval) ;
		
    	while(my $line=<$FF>) {
    		$line =~ /\W($oz_fstr)\W/  ;
    		next unless $1; 
    		$imsi = $1;
    		$sval = $1;
    		unless ( $dbHash{$imsi} ) {
    			$imsi = $ActionJsp{$imsi} if ($ActionJsp{$imsi}) ;
    			unless ( $dbHash{$imsi} ) {
    				$dbHash{$imsi} = $mHash{$imsi} if ($mHash{$imsi} ) ;
    			}    			
    		}
    		
      		next unless $imsi ;
      		next unless $dbHash{$imsi} ;
			$line =~ s/^\s+//;
			$line =~ s/[\t\r\n]/ /g;
    		for my $i ( 1..$dbHash{$imsi}->{cnt} ) {
    			printf $FHW ("%s\t%s\t%s\t%d\t%s\t%s\t%s\t$Loop\n", $dbHash{$imsi}->{$i} ,$dir, $_ , $. , $sval, $pgid,  $imsi) ;
    			$SW = 1;
    			if ( $mHash{$imsi} ) {
        			$ActionJsp{$pgid} = $imsi unless $ActionJsp{$pgid} ;
					delete $mHash{$imsi}->{method} ;
					delete $mHash{$imsi}->{cmdid} ;
        			$tHash{$imsi} = $mHash{$imsi} unless $tHash{$imsi}  ;
        		}
    				
    		}
	    }
	    close $FF ;
}

# 테이블,칼럼
sub file_analyzer_r2 {
	return if ( -d $_ ) ;

	if( /\.(java|jsp)$/i) {
		$TOT_CNT++ ;
		my ($line, %cls, %val, $cc, $bb, $clsid,$CLSnm) ;
		$cur_name = $_ ;
		print "**:$Loop: 작업중($TOT_CNT): $_\n" unless ($TOT_CNT%100);
    	open (my $FF,$_) or  print STDERR "** ERROR: $_ $!\n" and return ;
		$dir = $File::Find::dir;
		$dir =~ s!^\./?!! ;
		undef $CLSnm ;

    	while( $line=<$FF>) {
    		next if ($line =~ m!^\s*(?:\*|//|/\*|package|import)!) ;
			($line =~ /^\s*public\b.*\bclass\b\s*\b(\w+)\b/) and $CLSnm = $1 and $Loop > 1 and next ;
			chomp($line);
			$line =~ s/^\s+//;
			$line =~ s/\t/ /g;
			$line =~ s/\r/ /g;
   			if ($line =~ /\b($fstr)\b/) {
   				$cls{$1} = $.."\t".$line unless $cls{$1} ;
   			}
   			if (length($Vars)) {
     			if ($line =~ /[\s\W]+($Vars)[\s\W]+/) {
     				$val{$1} = $.." ".$line unless $val{$1} ;
     			}
   			}
   		}
	    close $FF ;
#	    $CLSnm = '' unless $CLSnm ;
   		if (substr($_,-3) eq 'jsp') {
   			for $bb (split (/\|/,$Vars) ) {$val{$bb}=' ';}
   		}
   		for $cc (keys %cls) {
   			if  ( scalar(keys %val) and length($Vars) ) {
     			for $bb (keys %val) {
     				$clsid = $cc.' '.$bb ;
     				if ( $dbHash{$clsid} ) {
                		for ( my $i=1; $i <= $dbHash{$clsid}->{cnt}; $i++ ) {
            				printf $FHW ("%s\t%s\t%s\t%s\t$Loop\n", $dbHash{$clsid}->{$i} ,$dir, $_ , $cls{$cc}.'  '.$val{$bb} ) ;
            				$SW = 1;
                		}
                		if ( $CLSnm ) {
                			my $imsi = $CLSnm.' '.$bb ;
                    		$tHash{$imsi} = $dbHash{$clsid} if ($cc ne $CLSnm and ! $dbHash{$imsi}) ;
                    		$tHash{$CLSnm} = $dbHash{$cc} if ($cc ne $CLSnm and ! $dbHash{$CLSnm}) ;
    #	               		delete  $tHash{$clsid} ;
    #	               		delete  $tHash{$cc} ;
						}
     				}
     			}
     		} else {
     				$clsid = $cc ;
     				if ( $dbHash{$clsid} ) {
                		for ( my $i=1; $i <= $dbHash{$clsid}->{cnt}; $i++ ) {
            				printf $FHW ("%s\t%s\t%s\t%s\n", $dbHash{$clsid}->{$i} ,$dir, $_ , $cls{$cc} ) ;
            				$SW = 1;
                		}
                		if ( $CLSnm ) {
	                		$tHash{$CLSnm} = $dbHash{$clsid} if ($cc ne $CLSnm and ! $dbHash{$CLSnm}) ;
#    	            		delete  $tHash{$clsid} ;
						}
     				}
     		}
   		}

	}
}

sub in_actionjsp {
    my $sfile = shift;
    open(IN,"<", $sfile) or print STDERR "\n** ($sfile) Action Mapping file 없음 **\n" and return ; 
    while(<IN>) {
    	my ($aa, $bb) = split /\t/,$_ ;
    	chomp($aa);
    	chomp($bb);
		$ActionJsp{$aa}=$bb ;
	}
	close (IN) ;
	printf "\n** Action Mapping %d read :$sfile **\n", scalar( keys %ActionJsp ) ;
}

sub hash_const {
    my $sfile = shift;
    my ($qid,$item,$i);
    open(IN,$sfile) || die "$! \n";
	<IN>;
    while(<IN>)
    {
        chomp;
        my %tmpHash;
        @tmpHash{qw(item dir pgid ln qid)} = (split(/\t/, $_))[0..3,5];
        $item = $tmpHash{item};
        if (substr($tmpHash{pgid},-4) eq 'java' and ! $tmpHash{qid}) {
        	$tmpHash{qid} = substr($tmpHash{pgid},0,-5) ;
        }
        $qid = $tmpHash{qid};
        next unless length($qid) ;

    	if ($dbHash{$qid}) {
    		for ( $i=1;$i <= $dbHash{$qid}->{cnt}; $i++) {
    			last if ($dbHash{$qid}->{$dbHash{$qid}->{cnt}} eq $item) ;
    		}
     		$dbHash{$qid}->{cnt} = $i if ($i > $dbHash{$qid}->{cnt});
     		$dbHash{$qid}->{$dbHash{$qid}->{cnt}} = $item ;
     	} else {
     		$dbHash{$qid} = \%tmpHash ;
     		$dbHash{$qid}->{cnt} = 1;
     		$dbHash{$qid}->{$dbHash{$qid}->{cnt}} = $item ;
		}
#		print "$qid,$dbHash{$qid}->{1}\n" ;
    }
    
    close(IN);
}

sub fstr_conj {
	my @Arr ;
    while (my ($aa,$bb) = (each %ActionJsp)) {
		  push (@Arr,$aa) if $dbHash{$bb} ;
    }

    @fList = sort {length($b) <=> length($a)} ((keys %dbHash), @Arr);
    @fList = Dawin::trim(@fList) ;
    $fstr = join ("|",@fList) ;
    $fstr =~ s/\./\\\./g ;
    $fstr =~ s!/!\\/!g ;

}

sub hash_const_r2 {
    my $sfile = shift;
    my ($cls, $clsid, $i,$tblcol);
    open(my $IN,"<",$sfile) || die "$! \n";
    while(<$IN>)
    {
    	next if (/DIR.+검색내용/) ;
        chomp;
        print $_ ;
        my %tmpHash;
        @tmpHash{qw(cls var tbl col)} = (split(/\t/, $_))[0..3];
        next unless $tmpHash{tbl} ;
        $cls = $tmpHash{cls} or next ;
        $clsid = $tmpHash{cls}.' '.$tmpHash{var};
        next unless length($clsid) ;
        $tblcol = $tmpHash{tbl}."\t".$tmpHash{col};

    	if ($dbHash{$clsid}) {
    		for ( $i=1;$i <= $dbHash{$clsid}->{cnt}; $i++) {
    			last if ($dbHash{$clsid}->{$dbHash{$clsid}->{cnt}} eq $tblcol) ;
    		}
     		$dbHash{$clsid}->{cnt} = $i if ($i > $dbHash{$clsid}->{cnt}) ;
     		$dbHash{$clsid}->{$dbHash{$clsid}->{cnt}} = $tblcol ;
     	} else {
     		$dbHash{$clsid} = \%tmpHash ;
     		$dbHash{$clsid}->{cnt} = 1;
     		$dbHash{$clsid}->{$dbHash{$clsid}->{cnt}} = $tblcol ;
		} 

    	if ($dbHash{$cls}) {
    		for ( $i=1;$i <= $dbHash{$cls}->{cnt}; $i++) {
    			last if ($dbHash{$cls}->{$dbHash{$cls}->{cnt}} eq $tblcol) ;
    		}
     		$dbHash{$cls}->{cnt} = $i if ($i > $dbHash{$cls}->{cnt}) ;
     		$dbHash{$cls}->{$dbHash{$cls}->{cnt}} = $tblcol ;
     	} else {
     		$dbHash{$cls} = \%tmpHash ;
     		$dbHash{$cls}->{cnt} = 1;
     		$dbHash{$cls}->{$dbHash{$cls}->{cnt}} = $tblcol ;
		} 
    }
    
    close($IN);
    

}
sub fstr_conj_r2 {
	@fList = () ;
	my ($clsid, $cc,$bb) ;
    for $clsid (keys %dbHash) {
    	my ($cc,$bb) = split (/\s+/,$clsid)  ;
    	push (@fList,$cc) if $cc ;
    }
    @fList = sort {length($b) <=> length($a)} @fList ;
    @fList = Dawin::trim(@fList) ;
    $fstr = join ("|",@fList) ;
    $fstr =~ s/\./\\\./g ;
	@fList = ();
    for $clsid (keys %dbHash) {
    	my ($cc,$bb) = split (/\s+/,$clsid)  ;
    	push (@fList,$bb) if $bb ;
    }
    @fList = sort {length($b) <=> length($a)} @fList ;
    @fList = Dawin::trim(@fList) ;
    $Vars = join ("|",@fList) ;
    $Vars =~ s/\./\\\./g ;
}

sub hash_const_r3 {
    my $sfile = shift;
    my ($cls,  $i, $tblcol, $crud);

    open(my $INF,"<",$sfile) or die "$! \n";
    while(<$INF>)
    {
    	next if (/Directory.+검색내용/) ;
    	
        chomp;
        my %tmpHash;
        @tmpHash{qw(itemA itemB pgid cls method DML)} = (split(/\t/, $_))[0,1,3,6,7,9];
        if (lc(substr($tmpHash{pgid},-4)) eq 'java' and ! $tmpHash{cls}) {
        	$tmpHash{cls} = substr($tmpHash{pgid},0,-5) ;
        }
				$crud = $tmpHash{DML} || '';
        $cls = $tmpHash{cls} or next ;
        $tblcol = $tmpHash{itemA}."\t".$tmpHash{itemB};

    	if ($dbHash{$cls}) {
				if ($tmpHash{method}) {
					$dbHash{$cls}->{method}->{$tmpHash{method}."\t".$tblcol} = $crud;
				} else {
					for ( $i=1;$i <= $dbHash{$cls}->{cnt}; $i++) {
						last if ($dbHash{$cls}->{$i} eq $tblcol) ;
					}
					$dbHash{$cls}->{cnt} = $i if ($i > $dbHash{$cls}->{cnt}) ;
					$dbHash{$cls}->{$i} = $tblcol ;
					$dbHash{$cls}->{$tblcol} = $crud ;
				}
     	} else {
     		$dbHash{$cls} = \%tmpHash ;
				if ($tmpHash{method}) {
					$dbHash{$cls}->{method} = { $tmpHash{method}."\t".$tblcol => $crud };
				} else {
					$dbHash{$cls}->{method} = {};
					$dbHash{$cls}->{cnt} = 1;
					$dbHash{$cls}->{1} = $tblcol ;
					$dbHash{$cls}->{$tblcol} = $crud ;
				}
#			undef $dbHash{$cls}->{method} if ( length($dbHash{$cls}->{method}) == 0 );
		 } 
    }
#    print  Dumper($dbHash{$cls}) ;
	close $INF;
}

sub fstr_conj_r3 {
	@fList = () ;
	my @Arr ;
	
    while (my ($aa,$bb) = (each %ActionJsp)) {
  		push (@Arr,$aa) if $dbHash{$bb} ;
    }
    @fList = sort {length($b) <=> length($a)} ((keys %dbHash),@Arr) ;
    @fList = Dawin::trim(@fList) ;
    $fstr = join ("|",@fList) ;
    $fstr =~ s/\./\\\./g ;

	@fList = () ;
    @fList = sort {length($b) <=> length($a)} (keys %ActionJsp) ;
    @fList = Dawin::trim(@fList) ;
    $oz_fstr = join ("|",@fList) ;
    $oz_fstr =~ s/\./\\\./g ;

}

1;
