use strict;
use warnings;
use 5.010 ;

#my	@dir = grep { -d } map { s!\\!/!g; glob }  split(/[, ]/,$ARGV[0]) ;
my @lstr = split (/\s+|\W/,"kjiuweiu\new873487skjsdkj", 2) ;

my $test = "asel    ect kjsd    kjds  delete       hh";
$test =~ s/\s+/ /g ;

$test =~ /\bdelete/;

say $test;
say $&;

say "@lstr"," ", scalar(@lstr);


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
		$lstr =~ /\b$tbl\s+(\w{1,6})\W/si and $alias = $1.'.' ;
print "alias=="; 
say $alias;
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
	$pstr =~ /\b$tbl\s+((?!where|group|order)\w+)\W/si and $alias = $1.'.' ;
say "alias==",$alias;
	return 1 if ($pstr =~ /[^\w.](?:$alias|$tbl\.)?$col\b.*$tbl\b|\b$tbl\s.*[^\w.](?:$alias|$tbl\.)?$col\b/si)  ;
	return 0 ;
}
