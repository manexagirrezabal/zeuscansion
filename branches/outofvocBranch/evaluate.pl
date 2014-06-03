#!/usr/bin/perl

use strict;
use FileHandle;
use IPC::Open2;
use locale;
use Getopt::Std;



my %opts;
getopts("g:t:hv",\%opts);
my @lineGV;
my @lineTV;
my $human=0;
$human=1 if (defined ($opts{h}));
if (defined($opts{v})) {
	print "Evaluate 13.6 version\n";
	exit;
}

if ((not defined $opts{g}) or (not defined $opts{t})) {
	print "Usage: perl evaluate.pl -g <GOLD STANDARD FILE> -t <TESTING FILE>\n";
	exit;
}

open (GOLD, $opts{g}) or die "I couldn't open the gold Standard file <<$opts{g}>>";
open (TEST, $opts{t}) or die "I couldn't open the test file <<$opts{t}>>";

my @textV;
my @strGV;
my @strTV;

my $correct=0;
my $notCorrect=0;
my $totalLines=0;
my $i=0;
while (my $lineG = <GOLD>){
	my $lineT = <TEST>;
	my ($lineGStr, $lineGTex) = split (/\t/, $lineG);
	my ($lineTStr, $lineTTex) = split (/\t/, $lineT);
	$textV[$i]=$lineGTex;
	
	@{$strGV[$i]}=split(/\|/, $lineGStr);
	@{$strTV[$i]}=split(/\|/, $lineTStr);
	
	if (compare ($strGV[$i], $strTV[$i]) == 0) {
		print "$lineGTex\t$lineGStr\t$lineTStr\t\tOK\n" if ($human);
		$correct++;
	}
	else {
		print "$lineGTex\t$lineGStr\t$lineTStr\t\tSHIT\n" if ($human);
		$notCorrect++;
	}
	$i++;
}

close (GOLD);
close (TEST);
my $correctSyllables = 0;
my $totalSyllables = 0;
foreach my $key (keys @textV) {
	chomp ($textV[$key]);
	my ($nS, $lu) = compareSyllBySyll($strGV[$key], $strTV[$key]);
	print $textV[$key]."\t".$nS."\t".$lu."\n" if ($human);
	$correctSyllables += ($lu - $nS);
	$totalSyllables += $lu;
}

print "\n\n" if ($human);

$totalLines = $correct + $notCorrect;

print "Absolutely correct lines:\n";
print "\tTotal nª of lines: $totalLines\n";
print "\tCorrect lines: $correct\n";
print "\tNot correct lines: $notCorrect\n";
print "\tPrecision: ".($correct/$totalLines)."\n";

print "\n\n";

print "Comparing it syllable by syllable:\n";
print "\tTotal number of syllables: $totalSyllables\n";
print "\tNumber of correctly scanned syllables: $correctSyllables\n";
print "\tPrecision: ".($correctSyllables/$totalSyllables)."\n";




sub compareSyllBySyll {
	my @ar1 = @{shift()};
	my @ar2 = @{shift()};
	my $ema = 9999999999;
	my $luz = 0;
	foreach my $el1 (@ar1) {
		foreach my $el2 (@ar2) {
			my $emaTenp = medcost ($el1, $el2);
			if ($ema > $emaTenp) {
				$ema = $emaTenp;
				$luz = length($el1);
			}
		}
	}
	return ($ema, $luz);
}

sub compare {
	my @ar1 = @{shift()};
	my @ar2 = @{shift()};
	foreach my $el1 (@ar1) {
		foreach my $el2 (@ar2) {
			if ($el1 eq $el2) {
				return 0;
			}
		}
	}
	return 1;
}

sub medcost {
    my $source = shift; my $target = shift;
    my $i; my $j;my $n = length($target); my $m = length($source);

    my $del_cost = 1;    my $sub_cost = 1;    my $ins_cost = 1;
    my @distance = ();
    $distance[0][0] = 0;
    for my $i (1 .. $m)  {
	$distance[$i][0] = $distance[$i-1][0] + $ins_cost;
    }
    
    for my $j (1 .. $n) {
	$distance[0][$j] = $distance[0][$j-1] + $del_cost;
    }
    for $j (1 .. $n) {
	for $i (1 .. $m) {
	    if (substr($source,$i-1,1) eq substr($target,$j-1,1)) {
		$distance[$i][$j] = $distance[$i-1][$j-1];
	    } else {
		$distance[$i][$j] = min($distance[$i-1][$j] + $ins_cost , $distance[$i-1][$j-1] + $sub_cost, $distance[$i][$j-1] + $del_cost);
	    }
	}
    }
    return ($distance[$m][$n]);
}

sub min {
    my $min = shift;
    $min = $min <= $_ ? $min : $_ for @_;
  return $min
}



