use 5.020;
use warnings;

use Net::HTTP;
use XML::Reader::RS qw(slurp_xml);

my $defname = 'A025_Def.xml';

my $aref = slurp_xml($defname,
  { root => '/podcast/mp3dir',     branch => [ '/@path' ]                  },
  { root => '/podcast/flist/feed', branch => [ '/@id', '/@name', '/@src' ] },
);

#~ say 'aref = ', Dumper($aref);

for my $feed (@{$aref->[1]}) {
    my ($host, $get) = $feed->[2] =~ m{\A http:// ([^/]+) (/ .*) \z}xms ? ($1, $2) :
      die "Error-0020: Can't parse /http://www.../ from '$feed->[2]'";

    say '===============================';
    #~ say 'id   = ', $feed->[0];
    #~ say 'name = ', $feed->[1];
    say 'src  = ', $feed->[2];
    #~ say 'host = ', $host;
    #~ say 'get  = ', $get;
    say '';

    #~ say '** Net::HTTP->new()...';
    my $http = Net::HTTP->new(Host => $host)
      or die "Error-0030: Can't Net::HTTP->new(Host => '$host') because $@";

    #~ say '** Net::HTTP->write_request()...';
    $http->write_request(GET => $get, 'User-Agent' => 'Mozilla/5.0');

    #~ say '** Net::HTTP->read_response_headers()...';
    my ($code, $msg, %h) = $http->read_response_headers;

    use Data::Dumper;
    #~ say 'code = ', $code;
    #~ say 'msg  = ', $msg;
    #~ say 'h    = ', Dumper(\%h);
    #~ say '';

    my $xml = '';
    my $ctr = 0;

    while (1) {
       my $rc = $http->read_entity_body(my $buf, 4096)
         // die "Error-0035: read failed because $!";

       last unless $rc;

       $ctr++;
       $xml .= $buf;

       #~ say 'buf  = ', (substr($buf, 0, 20) =~ s{\s+}' 'xmsgr), '...' if $ctr < 5;
    }

    #~ say '';
    #~ say substr($xml, 0, 1024);
    say 'len  = ', length($xml), ' bytes';
    #~ say '';

    my %IDRef;

    my $rdr = XML::Reader->new(\$xml, { filter => 2, strip => 1 });

    while ($rdr->iterate) {
        #~ printf "prf=%-1s, pat=%-37s, val=%-6s, tag=%-11s, t=%-1s, lvl=%2d\n",
        #~   $rdr->prefix, $rdr->path, $rdr->value, $rdr->tag, $rdr->type, $rdr->level;

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

    my $xref = slurp_xml(\$xml,
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
