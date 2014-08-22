use 5.020;
use warnings;

$ENV{'D_NAME'}   = 'descfile.txt';
$ENV{'D_WINDOW'} = 200;

system qq{perl A010_Log.pl};
