#!/usr/bin/perl -w
use utf8;
use strict;
use Data::Dumper;
use Getopt::Long;

use FindBin qw($Bin);
use lib "$Bin";

use Alignment::Model;

my $direction = 1;
my $autId = 1;
my $db = "annotations";

GetOptions(
    "author=i" => \$autId,
    "direction=i" => \$direction,
    "db=s" => \$db,
);

my $model = new Alignment::Model(
    author => $autId,
    direction => $direction,
    db => $db
);

my $query = $model->{dbh}->prepare("SELECT * FROM alignment");
$query->execute();
while(my $row = $query->fetchrow_hashref()) {
    my $VAR1;
    my @res1 = map { ($_->[0] - 1) . "-" . ($_->[1] - 1) } sort { $a->[1] <=> $b->[1] or $a->[0] <=> $b->[0] } @{eval($row->{"sure"})};
    my @res2 = map { ($_->[0] - 1) . "-" . ($_->[1] - 1) } sort { $a->[1] <=> $b->[1] or $a->[0] <=> $b->[0] } (@{eval($row->{"sure"})}, @{eval($row->{"probable"})});

    print $row->{a_id} - 1, "\t", join(" ", @res1), "\t", join(" ", @res2), "\n";
}