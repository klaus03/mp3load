use 5.020;
use warnings;

$ENV{'D_LOAD'} = 'MAX';

system qq{perl -C6 -MAcme::FixIO A020_Run.pl};
