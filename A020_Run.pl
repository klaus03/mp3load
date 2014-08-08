use 5.020;
use warnings;

use XML::Reader::RS qw(slurp_xml);

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                  },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@name', '/@src' ] },
);

for my $feed (@{$aref->[1]}) {
    my %IDRef;

    my $rdr = XML::Reader->new($feed->[2], { filter => 2, strip => 1 });

    while ($rdr->iterate) {
        if ($rdr->type eq 'T' and $rdr->level == 1) {
            $IDRef{'!tag'} = $rdr->tag;
        }
        elsif ($rdr->type eq '@' and $rdr->level == 2) {
            $IDRef{$rdr->tag} = $rdr->value;
        }

        last if $rdr->level == 1;
    }

    for (sort keys %IDRef) {
        printf "IDRef%-30s = %s\n", "{$_}", "'$IDRef{$_}'";
    }

    my $tag = $IDRef{'!tag'} // '';

    say '';
    say 'tag  = ', $tag;
    say '';

    unless ($tag eq 'rss') {
        die "Error-0099: Invalid tag = '$tag'";
    }

    my $xref = slurp_xml($feed->[2],
      { root => '/rss/channel', branch => [
        '/title',
        '/description',
        '/link',
      ] },
      { root => '/rss/channel/item', branch => [
        '/title',
        '/description',
        '/enclosure/@url',
        '/enclosure/@length',
        '/enclosure/@type',
        '/pubDate',
        '/guid',
      ] },
    );

    my $i = 0;

    printf "c-ti = %-120.120s\n", ($xref->[0][0][0]  // '') =~ s{\s+}' 'xmsgr;
    printf "c-ds = %-120.120s\n", ($xref->[0][0][1]  // '') =~ s{\s+}' 'xmsgr;
    printf "c-lk = %-120.120s\n", ($xref->[0][0][2]  // '') =~ s{\s+}' 'xmsgr;
    say '';

    printf "i-ti = %-120.120s\n", ($xref->[1][$i][0] // '') =~ s{\s+}' 'xmsgr;
    printf "i-ds = %-120.120s\n", ($xref->[1][$i][1] // '') =~ s{\s+}' 'xmsgr;
    printf "i-ur = %-120.120s\n", ($xref->[1][$i][2] // '') =~ s{\s+}' 'xmsgr;
    printf "i-ln = %-120.120s\n", ($xref->[1][$i][3] // '') =~ s{\s+}' 'xmsgr;
    printf "i-ty = %-120.120s\n", ($xref->[1][$i][4] // '') =~ s{\s+}' 'xmsgr;
    printf "i-da = %-120.120s\n", ($xref->[1][$i][5] // '') =~ s{\s+}' 'xmsgr;
    printf "i-gu = %-120.120s\n", ($xref->[1][$i][6] // '') =~ s{\s+}' 'xmsgr;
    say '';
}
