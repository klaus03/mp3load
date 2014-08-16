use 5.020;
use warnings;

$ENV{'D_SHOW'} = 'SHORT';
$ENV{'D_LOAD'} = 'MAX';

system qq{perl A020_Run.pl};
