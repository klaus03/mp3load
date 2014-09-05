use 5.020;
use warnings;

use HTML::Entities;
use Text::Fy::Utils qw(commify asciify);
use XML::Reader::RS qw(slurp_xml);
use File::Slurp;
use File::Copy;
use Term::Sk;
use Time::HiRes qw(time);

say '**********************';
say '** MP3Load (REPAIR) **';
say '**********************';
say '';

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                             },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@short', '/@name', '/@src' ] },
);

my %AList;
my %HList;

my $sk1 = Term::Sk->new('Loading %2d %25k', { freq => 'd', token => '' });

my $hctr = 0;

my $path = $aref->[0][0][0] // die "Error-0010: Can't find path '/podcast/mp3dir/\@path' in '$defname'";

my $logname = $path.'\\A_Data\\logfile.txt';
my $dscname = $path.'\\A_Data\\descfile.txt';
my $repname = $path.'\\A_Data\\repair.txt';

my $num;
my $max = scalar(@{$aref->[1]});

for (@{$aref->[1]}) { $num++;
    my $id    = $_->[0];
    my $short = lc $_->[1];
    my $name  = $_->[2];
    my $url   = $_->[3];

    $url =~ s{\?.* \z}''xms;
    $url =~ s{&.* \z}''xms;

    $sk1->token(sprintf('%-11s %3d (of %3d)', $id, $num, $max));

    my $full = $path.'\\P_'.$id;

    unless (-d $full) {
        mkdir $full or die "Error-0020: Can't mkdir '$full' because $!";
    }

    my $xref = eval {
      slurp_xml($url,
      { root => '/rss/channel', branch => [
        '/title',
        '/description',
        '/link',
      ] },
      { root => '/rss/channel/item', branch => [
        '/title',
        '/description',
        '/enclosure/@url',
        '/pubDate',
      ] } )
    };
    if ($@) {
        $sk1->whisper(sprintf("%-11s-> %s\n", $id, 
          'Error '.($@ =~ s{\A .* \s because \s+}''xmsr =~ s{\s+ at \s .* \z}''xmsr)));
        next;
    }

    for my $item (@{$xref->[1]}) {
        for (@$item) {
            next unless defined $_;

            for (m{(&\#?\w*;)}xmsg) {
                $AList{$_}++;
            }
        }

        my $title = asciify(decode_entities($item->[0]), [ 'iso' ]);
        my $desc  = asciify(decode_entities($item->[1]), [ 'iso' ]);
        my $link  = $item->[2];
        my $date  = lc($item->[3]);

        next unless defined($link) and $link =~ m{\.mp3 (?: \? |\z)}xms;

        unless ($short eq 'sk') {
            $desc  =~ s{< [^>]* >}' 'xmsg;
            $title =~ s{< [^>]* >}' 'xmsg;
        }

        $desc =~ s{\s+}' 'xmsg;
        $desc =~ s{\A \s}''xms;
        $desc =~ s{\s \z}''xms;

        $title =~ s{\s+}' 'xmsg;
        $title =~ s{\A \s}''xms;
        $title =~ s{\s \z}''xms;

        my $rdate = do {
            $date =~ m{\A [a-z]+, \s+ (\d+) \s+ ([a-z]+) \s+ (\d+) \s}xms
              or die "Error-0030: Can't parse date /jjj, jj mmm aaaa.../ from '$date'";

            my $dd   = $1;
            my $mon  = $2;
            my $yyyy = $3;

            my $mm =
              $mon eq 'jan' ?  1 :
              $mon eq 'feb' ?  2 :
              $mon eq 'mar' ?  3 :
              $mon eq 'apr' ?  4 :
              $mon eq 'may' ?  5 :
              $mon eq 'jun' ?  6 :
              $mon eq 'jul' ?  7 :
              $mon eq 'aug' ?  8 :
              $mon eq 'sep' ?  9 :
              $mon eq 'oct' ? 10 :
              $mon eq 'nov' ? 11 :
              $mon eq 'dec' ? 12 : die "Error-0040: Can't identify month ('$mon') from '$date'";

            sprintf '%02d%02d%02d', $yyyy % 100, $mm, $dd;
        };

        my $fname = $short.'-'.$rdate.'.mp3';

        $HList{$fname} = [ $link, \$title, \$desc ];
    }
}

$sk1->close;

open my $ifh, '<', $logname or die "Error-0050: Can't open < '$logname' because $!";
open my $ofh, '>', $repname or die "Error-0060: Can't open > '$repname' because $!";

while (<$ifh>) { chomp;
    next if m{\A -}xms;

    unless (m{\A \d{2} / \d{2} / \d{4} \s \d{2} : \d{2} : \d{2} \s (\S .*) \z}xms) {
        die "Error-0070: Can't parse /00/00/0000 00:00:00 .../ from '$_'";
    }

    my $data = $1;

    next if $data eq '*** download empty ***';

    unless ($data =~ m{\w+ \s* -> \s* ([a-z]{2} - \d{6} \.mp3)}xms) {
        die "Error-0080: Can't parse /zzzz -> aa-000000.mp3/ from '$data'";
    }

    my $z_name = $1;

    say {$ofh} $_;
    say {$ofh} '=' x 94;

    my $tk = $HList{$z_name};
    my $tot = $tk ? ${$tk->[1]}.' '.${$tk->[2]} : '?????????????????';

    my $ctxt  = '';
    my $cline = '';
    my $clen  = 100;

    for my $frag (split m{\s+}xms, $tot) {
        $cline .= ($cline eq '' ? '' : ' ').$frag;

        while (length($cline) > $clen) {
            my ($left, $right) = (substr($cline, 0, $clen), substr($cline, $clen));

            if ($left =~ m{\S \z}xms and $right =~ m{\A \S}xms) {
                ($left, $right) = $left =~ m{\A (.* \S) \s+ (\S+) \z}xms ? ($1, $2.$right) : ($cline, '');
            }

            $left  =~ s{\s+ \z}''xms;
            $right =~ s{\A \s+}''xms;

            if (length($left) > $clen) {
                my $part = substr($left, $clen);
                $part =~ s{\A \s+}''xms;

                $left = substr($left, 0, $clen);
                $right = ($part eq '' ? '' : $part.' ').$right;
            }

            $ctxt .= '  > '.$left."\n";
            $cline = $right;
        }
    }

    unless ($cline eq '') {
        $ctxt .= '  > '.$cline."\n";
    }

    say {$ofh} $ctxt;
}

close $ofh;
close $ifh;

my $nr = 0;

for my $he (sort keys %AList) { $nr++;
    my $ch = decode_entities($he);

    printf "%2d. %-10s => %5x %-8s %s\n", $nr, $he, ord($ch), "'$ch'", "'".asciify($ch, [ 'iso' ])."'";
}

say '';
