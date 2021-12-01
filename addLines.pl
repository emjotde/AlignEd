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

$model->{insert_document}->execute("whatever");
my $docId = $model->last_id();
$model->{insert_direction}->execute(1, 2);
my $dirId = $model->last_id();

print $docId, $dirId, "\n";

while(<STDIN>) {
    chomp;
    s/\r//g;

    my ($src, $trg) = split(/\t/, $_);
    $model->{insert_tu}->execute($docId);
    my $tuId = $model->last_id();

    $model->{insert_tuv}->execute($tuId, 1);
    my $tuvId1 = $model->last_id();
    $model->{insert_segment}->execute($tuvId1, $src);
    
    $model->{insert_tuv}->execute($tuId, 2);
    my $tuvId2 = $model->last_id();
    $model->{insert_segment}->execute($tuvId2, $trg);

    $Data::Dumper::Indent = 0;
    $model->{insert_alignment}->execute($tuId, $dirId, $autId, Dumper([]), Dumper([]));
}