use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

my ($file, $coords) = @ARGV;
open my $screen, '<', $file or die $!;
my @lines = <$screen>;
open my $cursor, '<', $coords or die $!;
my ($x, $y) = split / /, <$cursor>;

# tmux coordinates are zero-based; the input must follow all eight rows.
my $top = $y - 8;
die "No room above command\n" if $top < 0;
for my $row ($top..$y - 1) {
    die "Missing cat row $row\n" unless $lines[$row] =~ /\e\[(?:38|48);/;
    my $line = $lines[$row];
    $line =~ s/\e\[[0-9;?]*[A-Za-z]//g;
    chomp $line;
    die "Cat row contains input or is misaligned\n" if length($line) > 48;
}

my $input = $lines[$y];
$input =~ s/\e\[[0-9;?]*[A-Za-z]//g;
die "Cat on input row\n" if $input =~ /[\x{2500}-\x{259f}]/;
die "Missing prompt below cat\n" unless $input =~ /(?:[\$#%](?: |$)|>(?: |$))/;
print "PASS: eight cat rows above input, cursor column $x row $y\n";
