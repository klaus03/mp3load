use 5.020;
use warnings;

$ENV{'D_LOAD'} = 'SIZE';

system qq{perl -C6 -MAcme::FixIO A020_Run.pl};
