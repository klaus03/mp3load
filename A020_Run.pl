use 5.020;
use warnings;

use Encode qw(encode);
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
            last;
        }
        elsif ($rdr->type eq '@' and $rdr->level == 2) {
            $IDRef{$rdr->tag} = $rdr->value;
        }
        else {
            last;
        }
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

    my @schema = (
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

    my $xref = slurp_xml($feed->[2], @schema);

    for my $c (0..$#schema) {
        for my $d (0..$#{$xref->[$c]}) {
            last if $d >= 3; # <-- this 'last' is in place to print only 3 occurrences...

            for my $e (0..$#{$schema[$c]{'branch'}}) {
                my $text = encode('iso-8859-1', $xref->[$c][$d][$e]);

                printf "%-25.25s -> %1d. %-20.20s = %-60.60s\n",
                  $feed->[2], $c + 1, $schema[$c]{'branch'}[$e], $text;
            }

            say '';
        }
    }
}
