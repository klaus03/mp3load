use 5.020;
use warnings;

$ENV{'D_SHOW'} = 'SHORT';
$ENV{'D_LOAD'} = 'SIZE';

system qq{perl A020_Run.pl};