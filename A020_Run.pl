use 5.020;
use warnings;

use Encode qw(encode);
use XML::Reader::RS qw(slurp_xml);
use File::Slurp;
use Term::Sk;
use Time::HiRes qw(time);

my $Env_Load = $ENV{'D_LOAD'} // '';

unless ($Env_Load eq 'MIN' or $Env_Load eq 'SIZE' or $Env_Load eq 'MAX') {
    die "Error-0020: Invalid D_LOAD ('$Env_Load'), expected ('MIN', 'SIZE' or 'MAX')";
}

say '*****************************';
printf "** MP3Load (LOAD = %-6s) **\n", "'$Env_Load'";
say '*****************************';
say '';

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                             },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@short', '/@name', '/@src' ] },
);

my %Amp;
my @GList;

my $sk1 = Term::Sk->new('Loading %2d %25k', { freq => 'd', token => '' });

my $hctr = 0;

my $path = $aref->[0][0][0] // die "Error-0030: Can't find path '/podcast/mp3dir/\@path' in '$defname'";

my $logname = $path.'\\A_Data\\logfile.txt';

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
        mkdir $full or die "Error-0040: Can't mkdir '$full' because $!";
    }

    my $Latest;
    my %Exist;
    my @HList;

    for (read_dir($full)) { $_ = lc $_;
        next unless m{\A ([a-z]{2})-\d{6}\.mp3 \z}xms;
        next unless $1 eq $short;

        $Exist{$_}++;

        unless (defined($Latest) and $Latest ge $_) {
            $Latest = $_;
        }
    }

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

        next unless defined($link) and $link =~ m{\.mp3 (?: \? |\z)}xms;

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
            $c2 += $desc =~ s{&\#231;}{c}xmsg;
            $c2 += $desc =~ s{&\#8211;}{-}xmsg;
            $c2 += $desc =~ s{&\#8212;}{-}xmsg;
            $c2 += $desc =~ s{&\#8217;}{'}xmsg;
            $c2 += $desc =~ s{&\#8220;}{"}xmsg;
            $c2 += $desc =~ s{&\#8221;}{"}xmsg;
            $c2 += $desc =~ s{&\#8230;}{...}xmsg;

            $c2 += $desc =~ s{&quot;}{'}xmsg;
            $c2 += $desc =~ s{&lt;}{<}xmsg;
            $c2 += $desc =~ s{&gt;}{>}xmsg;
            $c2 += $desc =~ s{&nbsp;}{ }xmsg;
            $c2 += $desc =~ s{&ndash;}{-}xmsg;
            $c2 += $desc =~ s{&rsquo;}{'}xmsg;
            $c2 += $desc =~ s{&uuml;}{ue}xmsg;

            $c2 += $desc =~ s{&amp;}{&}xmsg;
        }

        my $rdate = do {
            $date =~ m{\A [a-z]+, \s+ (\d+) \s+ ([a-z]+) \s+ (\d+) \s}xms
              or die "Error-0050: Can't parse date /jjj, jj mmm aaaa.../ from '$date'";

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
              $mon eq 'dec' ? 12 : die "Error-0060: Can't identify month ('$mon') from '$date'";

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

    my $sctr = 0;

    for my $i (0..$#HList) { $sk1->up;
        local $_ = $HList[$i];

        if (defined $Latest) {
            next unless $_->[0] gt $Latest;
        }
        else {
            next unless $i == $#HList;
        }

        $sctr++;

        my $size = $Env_Load eq 'MIN' ? 0 : do { $sk1->up;
            require Acme::HTTP;
            %Acme::HTTP::Response = ();
            Acme::HTTP->new($_->[1]);
            $Acme::HTTP::Response{'Content-Length'} // 0;
        };

        push @GList, [ $id, $_->[0], $_->[1], $size, $_->[2], $_->[3] ];
    }

    if ($sctr) {
        $hctr++;
        $sk1->whisper(sprintf("%-11s-> %3d\n", $id, $sctr));
    }
}

$sk1->close;

say '' if $hctr;

my $t_size = 0;
my $t_sec  = 0;

for my $i (0..$#GList) {
    local $_ = $GList[$i];

    $t_size += $_->[3];
    my $leaf = $_->[2] =~ m{[\\/] ([^\\/]+) \z}xms ? $1 : '?';

    printf '%3d. (of %3d) ', $i + 1, scalar(@GList);

    my $p1 = sprintf '%-11.11s-> %-15.15s %10s Kb', $_->[0], $_->[1], commify(sprintf('%.0f', $_->[3] / 1024));
    print $p1;

    if ($Env_Load eq 'MAX') {
        my $sk2 = Term::Sk->new(' %5t.00 %2d %3p %20b', { freq => 'd', target => $_->[3] });

        my $watch_start = time;

        my $hdl = Acme::HTTP->new($_->[2])
          or die "Error-0070: Can't Acme::HTTP->new('$_->[2]') because $@";

        my $outname = $path.'\\P_'.$_->[0].'\\'.$_->[1];

        open my $ofh, '>', $outname or die "Error-0080: Can't open > '$outname' because $!";
        binmode $ofh;

        while (1) {
            my $ct = $hdl->read_entity_body(my $buf, 4096); # returns number of bytes read, or undef if IO-Error
            unless (defined $ct) {
                die "Error-0090: Can't Acme::HTTP->read_entity_body('$_->[2]') because $@";
            }

            last unless $ct;

            $sk2->up($ct);
            print {$ofh} $buf;
        }

        close $ofh;

        my $watch_stop = time;

        my $elaps = int(($watch_stop - $watch_start) * 100);

        $elaps = 1 if $elaps == 0;

        $t_sec += $elaps;

        $sk2->close;

        my $p2 = sprintf ' %8s (%10s Kb/sec)', show_sec($elaps), commify(sprintf('%0.f', $_->[3] / 10.24 / $elaps));
        print $p2;

        append_file($logname, sprintf('%-19.19s %s%s', dtime($watch_stop), $p1, $p2), "\n");
    }

    say '';
}

if (@GList) {
    printf "%42s %11s---", '-' x 42, '-' x 11;

    if ($Env_Load eq 'MAX') {
        printf " %8s %19s", '-' x 8, '-' x 19;
    }

    say '';

    printf "%-42s %11s Kb", '', commify(sprintf('%.0f', $t_size / 1024));

    if ($Env_Load eq 'MAX') {
        printf " %8s (%10s Kb/sec)", show_sec($t_sec), commify(sprintf('%0.f', $t_size / 10.24 / $t_sec));
    }

    say '';
    say '';
}
else {
    say '--- download empty ---';
    say '';

    if ($Env_Load eq 'MAX') {
        append_file($logname, sprintf('%-19.19s %s', dtime(time), '*** download empty ***'), "\n");
    }
}

if ($Env_Load eq 'MAX') {
    append_file($logname, '-' x 40, "\n");
}

if (%Amp) {
    say 'There were unidentified codes:';
    say '';

    my $i;

    for my $cd (sort keys %Amp) {
        for (@{$Amp{$cd}}) { $i++;
            printf "%3d. %-10s => %s\n", $i, $cd, "($_->[0], $_->[1], $_->[2])";
        }
    }

    say '';
}

sub commify {
    local $_ = shift;
    1 while s/^([-+]?\d+)(\d{3})/$1_$2/;
    return $_;
}

sub show_sec {
    my $r2 = $_[0] % 6000;

    return sprintf '%02d:%02d.%02d',
      int($_[0] / 6000), int($r2 / 100), $r2 % 100;
}

sub dtime {
    my $stamp = int($_[0]);

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($stamp);

    $mon++;
    $year += 1900;

    sprintf '%02d/%02d/%04d %02d:%02d:%02d', $mday, $mon, $year, $hour, $min, $sec;
}
