use 5.020;
use warnings;

use Encode qw(encode);
use XML::Reader::RS qw(slurp_xml);
use File::Slurp;

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                             },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@short', '/@name', '/@src' ] },
);

my %Amp;

my $path = $aref->[0][0][0] // die "Error-0010: Can't find path '/podcast/mp3dir/\@path' in '$defname'";

for (@{$aref->[1]}) {
    my $id    = $_->[0];
    my $short = lc $_->[1];
    my $name  = $_->[2];
    my $url   = $_->[3];

    my $full = $path.'\\P_'.$id;

    unless (-d $full) {
        mkdir $full or die "Error-0020: Can't mkdir '$full' because $!";
    }

    my $Latest;
    my %Exist;
    my @HList;

    for (read_dir($full)) { $_ = lc $_;
        next unless m{\A ([a-z]{2})_\d{6}\.mp3 \z}xms;
        next unless $1 eq $short;

        $Exist{$_}++;

        unless (defined($Latest) and $Latest le $_) {
            $Latest = $_;
        }
    }

    say '==============================';

    my $xref = slurp_xml($url,
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
      ] },
    );

    for my $item (@{$xref->[1]}) {
        my $title = encode('iso-8859-1', $item->[0]);
        my $desc  = encode('iso-8859-1', $item->[1]);
        my $link  = $item->[2];
        my $date  = lc($item->[3]);

        next unless $link =~ m{\.mp3 \z}xms;

        my $ctr = 0;

        unless ($short eq 'sk') {
            $ctr += $desc =~ s{< [^>]* >}''xmsg;
        }

        if ($short eq 'sn') {
            $desc =~ s{\s Q&A \s}' Q+A 'xmsg;
            $desc =~ s{\s  &  \s}' + 'xmsg;
        }

        $desc =~ s{\s+}' 'xmsg;
        $desc =~ s{\A \s}''xms;
        $desc =~ s{\s \z}''xms;

        my $c2 = 0;

        unless ($short eq 'sk') {
            $c2 += $desc =~ s{&\#8211;}{-}xmsg;
            $c2 += $desc =~ s{&\#8212;}{-}xmsg;
            $c2 += $desc =~ s{&\#8217;}{'}xmsg;
            $c2 += $desc =~ s{&\#8220;}{"}xmsg;
            $c2 += $desc =~ s{&\#8221;}{"}xmsg;
            $c2 += $desc =~ s{&\#8230;}{...}xmsg;

            $c2 += $desc =~ s{&quot;}{'}xmsg;
            $c2 += $desc =~ s{&lt;}{<}xmsg;
            $c2 += $desc =~ s{&gt;}{>}xmsg;

            $c2 += $desc =~ s{&amp;}{&}xmsg;
        }

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

        unless ($short eq 'sk') {
            for ($desc =~ m{[^&]{0,12} & [^&]{0,30}}xmsg) {
                my $code = m{(& [\#\w]+ ;)}xms ? $1 : '&???';
                push @{$Amp{$code}}, [ $id, $fname, $_ ];
            }
        }

        push @HList, [ $fname, $link, $title, $desc ];
    }

    @HList = sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @HList;

    for (@HList) {
        my $leaf = $_->[1] =~ m{[\\/] ([^\\/]+) \z}xms ? $1 : '?';

        printf "%-11.11s-> %-15.15s [%-25.25s] = %-20.20s => %-60.60s\n",
          $id, $_->[0], $leaf, $_->[2], $_->[3];
    }

    say '';
}

if (%Amp) {
    say 'There are unidentified codes:';
    say '';

    my $i;

    for my $cd (sort keys %Amp) {
        for (@{$Amp{$cd}}) { $i++;
            printf "%3d. %-10s => %s\n", $i, $cd, "($_->[0], $_->[1], $_->[2])";
        }
    }

    say '';
}
