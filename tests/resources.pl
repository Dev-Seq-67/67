use strict;
use warnings;
use Time::HiRes qw(time sleep);
use POSIX qw(sysconf _SC_CLK_TCK);
use JSON::PP;

# Sum CPU including reaped children; RSS is the sum, not unique shared memory.
sub snapshot {
    my ($root) = @_;
    my @queue = ($root);
    my %seen;
    my ($ticks, $rss, $threads, $fds, $count) = (0, 0, 0, 0, 0);
    my %by_pid;
    while (@queue) {
        my $pid = shift @queue;
        next if $seen{$pid}++;
        open my $stat, '<', "/proc/$pid/stat" or next;
        my $s = <$stat>;
        my ($name) = $s =~ /\((.*)\)/;
        $s =~ s/^.*\) //;
        my @p = split / /, $s;
        # After removing pid and comm, indices 11..14 are utime, stime,
        # cutime and cstime (clock ticks, including reaped children).
        $ticks += $p[11] + $p[12] + $p[13] + $p[14];
        $by_pid{$pid} = {name => $name, ticks => $p[11] + $p[12]};
        $count++;
        if (open my $status, '<', "/proc/$pid/status") {
            while (<$status>) {
                $rss += $1 if /^VmRSS:\s+(\d+)/;
                $threads += $1 if /^Threads:\s+(\d+)/;
            }
        }
        my @fd = glob "/proc/$pid/fd/*";
        $fds += @fd;
        if (open my $children, '<', "/proc/$pid/task/$pid/children") {
            push @queue, split /\s+/, (<$children> // '');
        }
    }
    return {ticks => $ticks, rss_kib => $rss, threads => $threads,
            processes => $count, fds => $fds, by_pid => \%by_pid};
}

my ($pid, $seconds, $label) = @ARGV;
die "Usage: resources.pl PID SECONDS LABEL\n" unless $pid && $seconds > 0;
my $hz = sysconf(_SC_CLK_TCK);
my $start = time;
my $first = snapshot($pid);
my %peak = %$first;
my $last;
while (time - $start < $seconds) {
    sleep 0.25;
    $last = snapshot($pid);
    for my $key (qw(rss_kib threads processes fds)) {
        $peak{$key} = $last->{$key} if $last->{$key} > $peak{$key};
    }
}
die "Measured process exited\n" unless $last->{processes};
my $elapsed = time - $start;
my @by_process;
for my $pid (sort keys %{$first->{by_pid}}) {
    next unless exists $last->{by_pid}{$pid};
    push @by_process, {
        name => $first->{by_pid}{$pid}{name},
        cpu_percent_one_core => 0 + sprintf('%.3f',
            100 * ($last->{by_pid}{$pid}{ticks} - $first->{by_pid}{$pid}{ticks}) / $hz / $elapsed)
    };
}
print JSON::PP->new->canonical->encode({
    label => $label, seconds => 0 + sprintf('%.3f', $elapsed),
    cpu_percent_one_core => 0 + sprintf('%.3f',
        100 * ($last->{ticks} - $first->{ticks}) / $hz / $elapsed),
    peak_rss_kib => $peak{rss_kib}, peak_threads => $peak{threads},
    peak_processes => $peak{processes}, peak_fds => $peak{fds},
    by_process => \@by_process
}), "\n";
