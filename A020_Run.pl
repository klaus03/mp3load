use 5.020;
use warnings;

use Encode qw(encode);
use XML::Reader::RS qw(slurp_xml);
use File::Slurp;
use LWP::UserAgent;
use Net::HTTP;
use Term::Sk;
use Time::HiRes qw(time);

my $Env_Show = $ENV{'D_SHOW'} // '';
my $Env_Load = $ENV{'D_LOAD'} // '';

unless ($Env_Show eq 'SHORT' or $Env_Show eq 'NORMAL' or $Env_Show eq 'LONG') {
    die "Error-0010: Invalid D_SHOW ('$Env_Show'), expected ('SHORT', 'NORMAL' or 'LONG')";
}

unless ($Env_Load eq 'MIN' or $Env_Load eq 'SIZE' or $Env_Load eq 'MAX') {
    die "Error-0020: Invalid D_LOAD ('$Env_Load'), expected ('MIN', 'SIZE' or 'MAX')";
}

say '**********************************************';
printf "** MP3Load (SHOW = %-8s, LOAD = %-6s) **\n", "'$Env_Show'", "'$Env_Load'";
say '**********************************************';
say '';

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                             },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@short', '/@name', '/@src' ] },
);

my %Amp;
my @GList;

my $sk1 = Term::Sk->new('Loading %2d %25k', { freq => 'd', token => '' });

my $path = $aref->[0][0][0] // die "Error-0030: Can't find path '/podcast/mp3dir/\@path' in '$defname'";

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
        next unless m{\A ([a-z]{2})_\d{6}\.mp3 \z}xms;
        next unless $1 eq $short;

        $Exist{$_}++;

        unless (defined($Latest) and $Latest le $_) {
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

    for my $i (0..$#HList) { $sk1->up;
        local $_ = $HList[$i];

        if (defined $Latest) {
            next unless $_->[0] gt $Latest;
        }
        else {
            next unless $i == $#HList;
        }

        my $size = $Env_Load eq 'MIN' ? 0 : do { $sk1->up;
            my $ua   = LWP::UserAgent->new;
            my $resp = $ua->request(HTTP::Request->new(HEAD => $_->[1]));
            my $len  = $resp->header('Content-Length') // 0;
            $len;
        };

        push @GList, [ $id, $_->[0], $_->[1], $size, $_->[2], $_->[3] ];
    }
}

$sk1->close;

my $t_size = 0;
my $t_sec  = 0;

for my $i (0..$#GList) {
    local $_ = $GList[$i];

    $t_size += $_->[3];
    my $leaf = $_->[2] =~ m{[\\/] ([^\\/]+) \z}xms ? $1 : '?';

    printf "%3d. (of %3d) %-11.11s-> %-15.15s",
      $i + 1, scalar(@GList), $_->[0], $_->[1];

    unless ($Env_Show eq 'SMALL') {
        printf " %10s Kb", commify(sprintf('%.0f', $_->[3] / 1024));
    }

    if ($Env_Load eq 'MAX') {
        my $sk2 = Term::Sk->new(' %8t %2d %3p %20b', { freq => 'd', target => $_->[3] });

        my $watch_start = time;

        my ($h1, $g1) = $_->[2] =~ m{\A http:// ([^/]+) (/ .*) \z}xms ? ($1, $2) :
          die "Error-0070: Can't parse /http://.../.../ from '$_->[2]'";

        my $hdl = Net::HTTP->new(Host => $h1)
          or die "Error-0080: Can't Net::HTTP->new(Host => '$h1') because $@";

        $hdl->write_request(GET => $g1, 'User-Agent' => 'Mozilla/5.0');
        my ($code, $msg, %h) = $hdl->read_response_headers;

        my $hloc = $h{'Location'};

        if (defined $hloc) {
            my ($h2, $g2) = $hloc =~ m{\A http:// ([^/]+) (/ .*) \z}xms ? ($1, $2) :
              die "Error-0090: Can't parse /http://.../.../ from '$hloc'";

            $hdl = Net::HTTP->new(Host => $h2)
              or die "Error-0100: Can't Net::HTTP->new(Host => '$h2') because $@";

            $hdl->write_request(GET => $g2, 'User-Agent' => 'Mozilla/5.0');
            $hdl->read_response_headers; # this function returns: $code, $msg, %h
        }

        my $outname = $path.'\\P_'.$_->[0].'\\'.$_->[1];

        open my $ofh, '>', $outname or die "Error-0110: Can't open > '$outname' because $!";
        binmode $ofh;

        while (1) {
            my $ct = $hdl->read_entity_body(my $buf, 4096); # returns number of bytes read, or undef if IO-Error
            unless (defined $ct) {
                die "Can't read_entity ('$h1', '$g1') because $!, $@";
            }

            last unless $ct;

            $sk2->up($ct);
            print {$ofh} $buf;
        }

        close $ofh;

        my $watch_stop = time;

        my $elaps = $watch_stop - $watch_start;
        $t_sec += $elaps;

        $sk2->close;

        printf " %8s", show_sec($elaps);
    }

    say '';
}

if (@GList) {
    printf "%-42s %11s---\n", '', '-' x 11;
    printf "%-42s %11s Kb\n", '', commify(sprintf('%.0f', $t_size / 1024));
    say '';
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
    my $r0 = int($_[0] * 100);
    my $r1 = $r0 % 360000;
    my $r2 = $r0 %   6000;

    return sprintf '%02d:%02d:%02d.%02d', int($r0 / 360000), int($r1 / 6000), int($r2 / 100), $r2 % 100;
}
