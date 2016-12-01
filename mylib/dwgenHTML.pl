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

die "!! $sfile �� ã���� �����ϴ�." unless -e $sfile;

DwgenHTML::start($src_path, $wdir, $sfile, $ftype ) ;

sub HELP_MESSAGE{
  die <<END;

������ �и��� �˻���� ���ϳ����� �������� HTML������ �����Ѵ�.
Usage: $0 [-a] [-o ���Dir] [-d �ҽ�����dir] -f �˻��������

-a  : �����˻�������� ó��(9���׸�)
-o ���Dir : ������ dir�� html ����
-d �ҽ�����Dir : �ҽ������� ��ġ root
-f �˻�������� : ������ �и��� CSV����(ù��°������ title�� ó����)
  ����)
    * �⺻
     TBL 	 COL 	 DIR 	 ���ϸ� 	 �ٹ�ȣ 	 �˻����� 	 �ڵ尪 
	* �����˻� ( -a �ɼ� )
     TBL 	 COL 	 DIR 	 ���ϸ� 	 �ٹ�ȣ 	 �˻����� 	 Class	�����˻���	���� 

END
}

