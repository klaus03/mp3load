use 5.020;
use warnings;

use XML::Reader::RS qw(slurp_xml);

say '*************';
say '** Logfile **';
say '*************';
say '';

my $window = 200;

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                             },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@short', '/@name', '/@src' ] },
);

my $path = $aref->[0][0][0] // die "Error-0010: Can't find path '/podcast/mp3dir/\@path' in '$defname'";

my $logname = $path.'\\A_Data\\logfile.txt';

my $ifh;

my $lines = 0;

open $ifh, '<', $logname or die "Error-0020: Can't open < '$logname' because $!";

while (<$ifh>) {
    $lines++;
}

close $ifh;

my $skip = $lines - $window;

my $ctr = 0;

open $ifh, '<', $logname or die "Error-0020: Can't open < '$logname' because $!";

while (<$ifh>) {
    $ctr++;
    next if $ctr <= $skip;

    print;
}

close $ifh;

say '';
