use warnings;
use strict;

die qq[Usage: perl $0 <file1> <file2>\n] unless @ARGV == 2;

my %file2_key;

open my $file2, "<", pop @ARGV or die qq[ERROR: Cannot open input file\n];

while ( <$file2> ) {
        my @f = split /\s*,\s*/, $_, 2;
        $file2_key{ $f[0] } = $_;
}

while ( <> ) {
        my @f = split /\s*,\s*/, $_, 2;
        if ( exists $file2_key{ $f[0] } ) {
                print $file2_key{ $f[0] };
                next;
        }

        print;
}

