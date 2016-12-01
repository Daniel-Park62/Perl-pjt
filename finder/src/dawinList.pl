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
my ($wfile,$exts);

getopts("htcxqo:e:",\%myopts);

#if ( defined($myopts{c}) ) {
	$Fn = \&Dawin::ExtCount ;
#}

if ( defined($myopts{o}) ) {
	$wfile = $myopts{o} ;
}

if ( defined($myopts{e}) ) {
	$exts = $myopts{e} ;
	$exts =~ s/,/|/g ;
	print $exts,"\n" ;
}

if ( defined($myopts{h}) ) {
	&HELP_MESSAGE();
	exit;
}	

my @dir = ('.')  ;
@dir = map { glob } @ARGV  if (@ARGV > 0) ;

print "�˻� directory --> $dir[0]\n";

my $TOT_CNT = 0 ;
$Fn->('init') ;

my ( $FHW,$ext ) ;
my	$Fn1 = \&print_if_file ;
STDOUT->autoflush() ;
if ( defined($wfile) ) {
  print "** ������� --> $wfile \n";
  open($FHW,">",$wfile) || die "$wfile $! \n";
}  else {$FHW = *STDOUT;}
$FHW->autoflush() ;

if  ( defined($myopts{q}) ) {
	$Fn1 = \&inspect_query ;
	print $FHW " DIR \t ���ϸ� \t Query \n" ;
} elsif  ( defined($myopts{x}) ) {
	$Fn1 = \&inspect_table ;
	print $FHW " DIR \t ���ϸ� \t Table \n" ;
} elsif  ( ! defined($myopts{c}) ) {
	print $FHW " DIR \t ���ϸ� \t Ȯ���� \t ������ " ;
	if (defined($myopts{t})) {
		print $FHW "\t ���뼳�� \n" ;
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
	if ($exts) { return unless /($exts)$/ ; }
	
	$Fn->('count',$_) ;
	return if ( defined($myopts{c}) );

	my $sz = -s ;
	my $ldir = $File::Find::dir;
#	$ldir =~s!^$dir/?!! ;
	$ldir =~ s!^\.{1,2}/?!! ;
	($ext) = ($_ =~ /.*\.(.*)$/) ;
	$ext = '' unless $ext ;
	printf $FHW ("%s\t%s\t%s\t$sz", $ldir, $_ , $ext );
	if ( defined($myopts{t}) ) {
		my @rmk = search_title() ;
		print  $FHW "\t$rmk[0]\t@rmk[1..$#rmk]" ;
	}
	print $FHW "\n" ;
}

sub inspect_table {
	return if ( -d || /\.(txt|log|exe|pdf|bak|tar|jar|jpg|png|ico|bmp|jpeg|xpm)?$/i || /\d{8,}/ ) ;
	return if (-s > 100000000);
	if ($exts) { return unless /($exts)$/ ; }

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
	return if (-s > 100000000);

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

sub search_title {
	my @res = (' ') ;
	return @res if (-s > 100000000);
  	open (my $FF,$_) or print STDERR "\n** ERROR: $File::Find::name $!\n" and return ;

	my $ls = "";
	if ( /htm$/ ) {
		local $/  ;
		$ls = <$FF> ;
		@res = (($ls =~ /ncDoc_setTitle\(\s*"(.*?)"/s or $ls =~ /��\s*��\s*:?(.*)$/m) ,  $ls =~ /program_id"\s*,\s*"(.*?)"/mg ) ;
#		$ls =~ /ncDoc_setTitle\("(.*?)"/m ;
#		unshift(@res, $1) ;
	} else {
		foreach (1..60) {
			$ls .=<$FF> || last ;
		}
		$ls =~ /��\s*��\s*:\s*(.*)\*?.*?$/m ;
		$ls =~ /�ý���\s*��\s*:\s*(.*)\*?.*?$/m unless ($1) ;
		$ls =~ /���α׷�\s*��\s*:\s*(.*)\*?.*?$/m unless ($1) ;
		$res[0] = $1 ;
	}
    close $FF ;
	foreach (@res) { s/\s/ /g if ($_) ;} 

	$res[0] = ' ' unless $res[0] ;
	return @res ;
}

sub HELP_MESSAGE(){
  print <<END;

������ ���丮�� ���ϸ���Ʈ�� ����Ѵ�.

    Usage: $0 [[-x],[-c][-t]] [-o �������] [-e Ȯ����1,Ȯ����2..] [�˻�DIR]

    -c : Ȯ���ں� ���ϼ� ���踸 ���
    -t : ���μ����� ���(����, �ý��۸�, ���α׷����� ã�� ���� ǥ��)
    -o : ������� : ������ ���Ϸ� �˻���� ���� ����
    -e : Ȯ����   : ������ Ȯ���ڸ� ���
    -x : Query �� ������̺� ����� �����Ѵ�. (-c -t ���õȴ�)
   
    �˻�DIR�� ������ ����DIR���� �˻�������.
	
END
}

$SIG{INT} = sub {
		close($FHW) if defined $FHW ;
        die "\n����� Abort.\n";
};
