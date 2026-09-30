use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

my ($file, $command) = @ARGV;
open my $f, '<', $file or die $!;
my ($fg_rgb, $bg_rgb, $reverse, $found) = (0, 0, 0, 0);
while (my $line = <$f>) {
    my $text = '';
    my @colors;
    while (length $line) {
        if ($line =~ s/^\e\[([0-9;?]*)([A-Za-z])//) {
            my ($params, $kind) = ($1, $2);
            if ($kind eq 'm') {
                my @p = split /;/, $params;
                @p = (0) unless @p;
                while (@p) {
                    my $p = shift @p;
                    if ($p == 0) { $fg_rgb = $bg_rgb = $reverse = 0; }
                    elsif ($p == 7) { $reverse = 1; }
                    elsif ($p == 27) { $reverse = 0; }
                    elsif ($p == 39) { $fg_rgb = 0; }
                    elsif ($p == 49) { $bg_rgb = 0; }
                    elsif ($p == 38 || $p == 48) {
                        my $mode = shift @p;
                        my $rgb = defined($mode) && $mode == 2;
                        splice @p, 0, $rgb ? 3 : 1;
                        if ($p == 38) { $fg_rgb = $rgb; } else { $bg_rgb = $rgb; }
                    }
                    elsif ($p >= 30 && $p <= 37 || $p >= 90 && $p <= 97) { $fg_rgb = 0; }
                    elsif ($p >= 40 && $p <= 47 || $p >= 100 && $p <= 107) { $bg_rgb = 0; }
                }
            }
            next;
        }
        $text .= substr($line, 0, 1, '');
        push @colors, $fg_rgb || $bg_rgb || $reverse;
    }
    my $at = index($text, $command);
    next if $at < 0;
    $found++;
    die "Sprite colors leaked onto accepted command: $command\n"
        if grep { $_ } @colors[$at..$at + length($command) - 1];
}
die "Accepted command not found in terminal capture: $command\n" unless $found;
print "PASS: accepted command has no sprite RGB colors ($command)\n";
