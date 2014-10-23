#!/usr/bin/perl

use strict;
use FileHandle;
use IPC::Open2;
use locale;
use Getopt::Std;


my %opts;
getopts("c:e:psfnahvS",\%opts);

my $numericView = 0;
my $stressView = 0;
my $processView = 0;
my $scorePerFeet = 0;
my $additionalInformation = 0;
my $eval = 0;
my $silent = 0;
my $corpus = $opts{c};

$numericView = 1 if (defined($opts{n}));
$stressView = 1 if (defined($opts{s}));
$processView = 1 if (defined($opts{p}));
$scorePerFeet = 1 if (defined($opts{f}));
$additionalInformation = 1 if (defined($opts{a}));
$eval = 1 if (defined($opts{e}));
$silent = 1 if (defined($opts{S}));

help() if (defined($opts{h}));
version() if (defined($opts{v}));
welcome() if ($silent==0);
noInput() if (not defined($opts{c}));


my $wholeText = "";
my $tokenizedText = "";
my @wordV = ();
my @posV = ();
my @firstStepRes = ();
my @secondStepRes = ();
my @returnStep = ();
my @lineV = ();
my @femLineV = ();
my @syllV = ();
my @stressRes = ();
my @lines = ();
my ($word, $pos);
my $eachLine;
my %lineStress;
my $interm;
my $nLines=0;
my $totalSyllsMean;
my $totalSyllsMeanInt;
my $stdDev;
my $totalFeet;
my %struc;
my %count;
my %sum;
my %syllCount;
my $diSylScore = 1.0; ##ADJUSTABLE PARAMETERS
my $triSylScore = 1.5; ##ADJUSTABLE PARAMETERS
my $tetraSylScore = 2.0; ##ADJUSTABLE PARAMETERS



my %conf;

open (CONF, "zeuscansion.conf") or die "I can not open the configuration file";
while (<CONF>){
    chomp;
    my ($name, $value) = split /\s*\=\s*/, $_;
    $conf{"$name"} = $value;
}
close (CONF);

open (INFILE, $corpus) or die "I couldn't open the poem file";
open2(*ReaderTokenizer, *WriterTokenizer, "flookup -i -x -b transducers/01tokenizer.fst");
open2(*ReaderPrimary, *WriterPrimary, "flookup -i -x -b transducers/grovesRules.fst");
open2(*ReaderPrimary2, *WriterPrimary2, "flookup -i -x -b transducers/grovesRules.fst");
#open2(*ReaderSecondary, *WriterSecondary, "flookup -i -x -b transducers/03secondaryStep.fst");
open2(*ReaderClose, *WriterClose, "flookup -i -b -x -a transducers/closewordtest.fst");
open2(*ReaderClean, *WriterClean, "flookup -i -b -x transducers/cleanAll.fst");
open2(*ReaderPOS, *WriterPOS, "hunpos-tag ".$conf{"HMM_POS_MODEL"});


############################################################################################
##################################READING THE TEXT##########################################
############################################################################################
while (my $lerro = <INFILE>) {
  chomp ($lerro);
  $wholeText .= lc($lerro)." <s> "; # Everything2lc
}

$wholeText =~ s/^\s*//;

print "I've read the text!!\n" if ($silent==0);



#TOKENIZE THE TEXT
print WriterTokenizer $wholeText."\n";

while ((my $returnword = <ReaderTokenizer>) ne "\n") {
  chomp ($returnword);
  if ($returnword =~ m/[a-zA-Z]+/) { #FILTER NON-LETTER CHARACTERS

      if ($returnword eq 'i') { # IF A TOKEN IS 'i', IT IS THE PRONOUN "I"
	  $returnword = "I";
      }

    push (@wordV, $returnword);
  }
}


$tokenizedText = join ("\n", @wordV);

print "I've tokenized the text!!\n" if ($silent==0);

#POS-TAGGING OF TOKENS, USING HUNPOS HMM-TAGGER
print WriterPOS $tokenizedText."\n\n";

while ((my $returnword = <ReaderPOS>) ne "\n") {
    chomp ($returnword);
    ($word, $pos) = split (/\t/, $returnword);
    push (@posV, $pos);

}

print "I've extracted the POS tags!!\n" if ($silent==0);

#Rhythmi-metrical scansion
#Groves' rules

#1ST STEP
for (my $i=0; $i<scalar(@posV); $i++) {

    if ($wordV[$i] eq 'I') {
	$wordV[$i] = "i";
    }

  print WriterPrimary $wordV[$i]."+".$posV[$i]."\n";
  while ((my $returnword = <ReaderPrimary>) ne "\n") {
    chomp ($returnword);
    if ($returnword ne "+?") {
      $firstStepRes[$i] = $returnword;
      $secondStepRes[$i] = $returnword;
    }
    else { #PROBLEM: I don't know the stress pattern of word $wordV[$i]!
           #SOLUTION: I can search similar words using the closewordtest.fst transducer
      print WriterClose $wordV[$i]."\n";
      while ((my $returnClose = <ReaderClose>) ne "\n") {
        chomp ($returnClose);
        $interm = $returnClose;
      }


      print WriterPrimary2 $interm."+".$posV[$i]."\n";
      while ((my $returnPrim = <ReaderPrimary2>) ne "\n") {
        chomp ($returnPrim);
        if ($returnPrim ne "+?") {
          $firstStepRes[$i] = $returnPrim;
          $secondStepRes[$i] = $returnPrim;
        }
        else {
          $firstStepRes[$i] =  "?";
          $secondStepRes[$i] =  "?";
        }

      }
    }
  }
}

print "I've applied the Groves' rules!\n" if ($silent==0);

#CLEANUP STEP
for (my $i=0; $i<scalar(@posV); $i++) {
  print WriterClean $secondStepRes[$i]."\n";
  while ((my $returnword = <ReaderClean>) ne "\n") {
    chomp ($returnword);
    if ($returnword ne "+?") {
      $returnStep[$i] = $returnword;
    }
    else {
      $returnStep[$i] =  "?";
    }
  }
}

print "CleanUp!!\n" if ($silent==0);

$eachLine = "";
my $eachText = "";
my @textLines = ();
for (my $i=0; $i<scalar(@posV); $i++) {
  if ($wordV[$i] eq "<s>") {
    $nLines++;
    if ($eachLine !~ m/[A-Z]/) {
   	  $eachLine =~ s/[^[a-zA-Z]]//gi;
      $lineStress{$eachLine}++;
      $lineV[$nLines] = $eachLine;
      $syllV[$nLines] = scalar(split (//, $eachLine));
      $textLines[$nLines] = $eachText;
      if ($eachLine =~ m/(\'\-|\`\-)$/g) {
      	$femLineV[$nLines] = 1;
      }
      else {
      	$femLineV[$nLines] = 0;
      }
    }
    $eachLine = "";
    $eachText = "";
  }
  else {
    $eachLine .= $returnStep[$i];
    $eachText .= $wordV[$i]." ";
  }  
}



print "----------------------------ANALYSIS FINISHED------------------------------------\n" if ($silent==0);
print "Press ENTER to continue...\n" if ($silent==0);
<STDIN> if ($silent==0);


#IKUSTEKO // VIEW
if ($stressView) {
  my $counter = 1;
  print "Line $counter:   ";
  for (my $i=0; $i<scalar(@posV); $i++) {
    if ($wordV[$i] eq "<s>") {
      $counter++;
      print "\nLine $counter:   ";
    }
    else {
      print $returnStep[$i]." ";
    }  
  }
  print "\n\n";
}



if ($processView) {
  for (my $i=0; $i<scalar(@posV); $i++) {
    if ($wordV[$i] eq "<s>") {
      print "\n";
    }
    else {
      print $wordV[$i]."\t";
      print $wordV[$i]."+";
      print $posV[$i]."\t";
      print $firstStepRes[$i]."\t";
      print $secondStepRes[$i]."\t";
      print $returnStep[$i]."";
    }  
    print "\n";
  }
  print "\n\n";
}



foreach my $elem (sort {$lineStress{$a} cmp $lineStress{$b} } keys %lineStress)
{
  my @elemV = split (//, $elem);
  for (my $i=0; $i<scalar(@elemV); $i++) {
  	if ($elemV[$i] eq "'") {
  		$stressRes[$i] += (2*$lineStress{$elem});
  	}
  	elsif ($elemV[$i] eq "`") {
  		$stressRes[$i] += $lineStress{$elem};
  	}
  	elsif ($elemV[$i] eq "-") {
  		$stressRes[$i] += 0;
  	}
  }
}



print "Numeric syllable emphasis: " if ($numericView);
my $max = 0;
for (my $i=0; $i<scalar(@stressRes); $i++) {
	print $stressRes[$i]."\t" if ($numericView);
	if ($stressRes[$i] > $max) {
		$max = $stressRes[$i];
	}
}
print "\n" if ($numericView);

my @normalizedStress;
my $stress = "";
for (my $i=0; $i<scalar(@stressRes); $i++) {
	print $stressRes[$i]/$max." " if ($numericView);
    $normalizedStress[$i] = $stressRes[$i]/$max;
	if (($stressRes[$i]/$max) <= 0.5) {
		$stress .= "_";
	}
	else {
		$stress .= "'";
	}
}
print "\n\n" if ($numericView);

#for (my $i=0; $i<scalar(@stressRes)-1; $i++) {
#    print $normalizedStress[$i+1]-$normalizedStress[$i]."\n";
#}
#print "\n\n";

my $oldStress = $stress;
$stress =~ s/__*$/_/; #PROBLEM OF SINGLE LONG SENTENCES

#DISYLLABLE STRUCTURES
$struc{"pyrrhus"} = "__"; #PYRRHUS
$sum{"pyrrhus"} = $diSylScore;
$syllCount{"pyrrhus"} = 2;
$struc{"iamb"} = "_'"; #IAMB
$sum{"iamb"} = $diSylScore;
$syllCount{"iamb"} = 2;
$struc{"trochee"} = "'_"; #TROCHEE
$sum{"trochee"} = $diSylScore;
$syllCount{"trochee"} = 2;
$struc{"spondee"} = "''"; #SPONDEE
$sum{"spondee"} = $diSylScore;
$syllCount{"spondee"} = 2;
#TRISYLLABLE STRUCTURES
$struc{"tribrach"} = "___"; #TRIBRACH
$sum{"tribrach"} = $triSylScore;
$syllCount{"tribrach"} = 3;
$struc{"dactyl"} = "'__"; #DACTYL
$sum{"dactyl"} = $triSylScore;
$syllCount{"dactyl"} = 3;
$struc{"amphibrach"} = "_'_"; #AMPHIBRACH
$sum{"amphibrach"} = $triSylScore;
$syllCount{"amphibrach"} = 3;
$struc{"anapaest"} = "__'"; #ANAPAEST
$sum{"anapaest"} = $triSylScore;
$syllCount{"anapaest"} = 3;
$struc{"cretic"} = "'_'"; #CRETIC
$sum{"cretic"} = $triSylScore;
$syllCount{"cretic"} = 3;
$struc{"molossus"} = "'''"; #MOLOSSUS
$sum{"molossus"} = $triSylScore;
$syllCount{"molossus"} = 3;
$struc{"bacchius"} = "_''"; #BACCHIUS
$sum{"bacchius"} = $triSylScore;
$syllCount{"bacchius"} = 3;
$struc{"antibacchius"} = "''_"; #ANTIBACCHIUS
$sum{"antibacchius"} = $triSylScore;
$syllCount{"antibacchius"} = 3;

foreach my $el (keys %struc) {
	$count{$el}+=$sum{$el} while ($stress =~ m/$struc{$el}/g);
}

print "\nSCORE PER FEET:\n" if ($scorePerFeet);;
my $maxcount = 0;
my $maxname;
foreach my $el (sort {$count{$b} <=> $count{$a}} keys %count) {
	if ($maxcount < $count{$el}) {
		$maxcount = $count{$el};
		$maxname = $el;
	}
	print "$el\t$count{$el}\n" if ($scorePerFeet);
}
print "\n" if ($scorePerFeet);

$totalSyllsMean = mean(\@syllV, scalar(@syllV)-1);
$totalSyllsMeanInt = round($totalSyllsMean);
$stdDev = stdev(\@syllV, scalar(@syllV)-1);
my $stdDevInt = round($stdDev);




print "Syllable emphasis $oldStress \n" if ($silent==0);
print "Meter: " if ($silent==0);

if (($maxname eq 'iamb') or ($maxname eq 'trochee')) {
	if (($count{"iamb"} != 0) && ($count{"iamb"} == $count{"trochee"})) {
		if ($stress =~ m/^_/) {print "Iambic "; $maxname='iamb';}
		else {print "Trochaic ";$maxname='trochee';}
	}
	else {
		if ($maxname eq 'iamb') {print "Iambic "; $maxname='iamb';}
		else {print "Trochaic ";$maxname='trochee';}
	}
}
elsif ($maxname eq 'pyrrhus') {print "Pyrrhic ";}
elsif ($maxname eq 'spondee') {print "Spondic ";}
elsif ($maxname eq 'tribrach') {print "Tribrach ";}
elsif ($maxname eq 'dactyl') {print "Dactylic ";}
elsif ($maxname eq 'amphibrach') {print "Amphibraic ";}
elsif ($maxname eq 'anapaest') {print "Anapaestic ";}
elsif ($maxname eq 'cretic') {print "Cretic ";}
elsif ($maxname eq 'molossus') {print "Molossus ";}
elsif ($maxname eq 'bacchius') {print "Bacchic ";}
elsif ($maxname eq 'antibacchius') {print "Antibacchic ";}

$totalFeet = int ($totalSyllsMeanInt / $syllCount{$maxname});

print "monometer\n" if ($totalFeet == 1);
print "dimeter\n" if ($totalFeet == 2);
print "trimeter\n" if ($totalFeet == 3);
print "tetrameter\n" if ($totalFeet == 4);
print "pentameter\n" if ($totalFeet == 5);
print "hexameter\n" if ($totalFeet == 6);
print "heptameter\n" if ($totalFeet == 7);
print "octameter\n" if ($totalFeet == 8);

print "SUPER SYLLABLES (before): $oldStress\n" if ($silent==0);
$oldStress =~ s/($struc{$maxname})_*$/$1/;
print "SUPER SYLLABLES $struc{$maxname} (after): $oldStress\n" if ($silent==0);

print "\n" if ($additionalInformation);
print "The poem has $nLines lines\n" if ($additionalInformation);
print "The poem has $totalSyllsMean, $totalSyllsMeanInt syllables per line on average\n" if ($additionalInformation);
print "The standard deviation of the syllable distribution is $stdDev $stdDevInt\n" if ($additionalInformation);

close (INFILE);
close(ReaderTokenizer); close(WriterTokenizer);
close(ReaderPOS); close(WriterPOS);
close(ReaderPrimary);close(WriterPrimary);
close(ReaderPrimary2);close(WriterPrimary2);
#close(ReaderSecondary);close(WriterSecondary);
close(ReaderClose);close(WriterClose);
close(ReaderClean);close(WriterClean);

if ($eval == 1) {
	print "\n\n\n";
	print "EVALUATION:\n";
	print "...........\n";
	open (FILEVAL, ">$opts{e}") or die "Oh, I couldn't open the $opts{e} file";
	
	for (my $i=1; $i<scalar(@lineV); $i++) {
		my $write = $lineV[$i];
		$write =~ s/['`]/+/g;
		my $toprint = $write."\t".$textLines[$i]."\n";
		print ">>EV>> ".$toprint;
		print FILEVAL $toprint;
	}
	
	close (FILEVAL);
	print "...........\n";
}







####AUXILIAR FUNCTIONS

sub noInput {
	print "Usage: perl zeuscansion.pl -c <POEM> [options]\n";
	print "\t-p\tScansion chain\n";
	print "\t-s\tStress patt/line\n";
	print "\t-n\tNº values of stress\n";
	print "\t-a\tAdditional inf.\n";
	print "\t-f\tScore/metrical patt.\n";
	print "\t-e\tEvaluation\n";
	print "\n";
	print "More information at:\n";
	print "\tperl zeuscansion.pl -h\n";
	print "\thttp://zeuscansion.googlecode.com\n";
	exit;
}

sub welcome {
	print "ZeuScansion, version 13.6\n";
	print "Manex Agirrezabal\n";
	print "There is ABSOLUTELY NO WARRANTY\n";
	print "Use -h option for help\n\n\n";
}

sub help {
	my $osa = "                 ";
	print "\n\n\n";
	print $osa."#############################################################################################\n";
	print $osa."#                                                                                           #\n";
	print $osa."#                              ZEUSCANSION: ENGLISH POETRY ANALYZER                         #\n";
	print $osa."#                                                                                           #\n";
	print $osa."# Usage: perl zeuscansion.pl -c <POEM> [options]                                            #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        OPTIONS:                                                                           #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -p View of the scansion chain (POS tagging, Groves' steps (1, 2), CleanUp)         #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -s Stress patterns per line                                                        #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -n Numeric values of stress                                                        #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -a Show additional information                                                     #\n";
	print $osa."#           (Total sum of lines, Syll/line avg., Syll distribution Std. dev.)               #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -f Show matches and score per metrical pattern                                     #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        -e <FILE> create FILE for evaluation                                               #\n";
	print $osa."#           How to evaluate:                                                                #\n";
	print $osa."#           Create gold standard file in ZEUSC format                                       #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        ZEUSC FORMAT: (Example at goldExample.txt file)                                    #\n";
	print $osa."#          Stress pattern <TAB> poetry line                                                 #\n";
	print $osa."#          Stress pattern format: (weak stress=\"-\", strong stress=\"+\")                      #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#        EVALUATION PROCESS:                                                                #\n";
	print $osa."#        \$~ cat <GOLDFILE> | cut -f 2 > testTexts/<GOLDTEXTFILE>                            #\n";
	print $osa."#        \$~ perl zeuscansion.pl -c testTexts/<GOLDTEXTFILE> -e <ZEUSCANNEDGOLD>             #\n";
	print $osa."#        \$~ perl evaluate.pl -g <GOLDFILE> -t <ZEUSCANNEDGOLD> [-h]                         #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#                                                                                           #\n";
	print $osa."# Author: Manex Agirrezabal                                                                 #\n";
	print $osa."#                                                                                           #\n";
	print $osa."# Site: https://zeuscansion.googlecode.com                                                  #\n";
	print $osa."#       https://sites.google.com/site/manexagirrezabal/                                     #\n";
	print $osa."#                                                                                           #\n";
	print $osa."# Reviewers: Mans Hulden                                                                    #\n";
	print $osa."#            Bertol Arrieta                                                                 #\n";
	print $osa."#            2013/03/19                                                                     #\n";
	print $osa."#                                                                                           #\n";
	print $osa."# License: GPL v2                                                                           #\n";
	print $osa."#                                                                                           #\n";
	print $osa."#############################################################################################\n";
	print "\n\n\n";
	exit;
}

sub version {
	print "ZeuScansion 13.6 version\n";
	exit;
}

sub normalize {
	my @strV = @{shift()};
	my $sum = sum(\@strV);
	my @res = ();
	foreach my $el (keys @strV) {
		$res[$el] = $strV[$el]/$sum;
	}
	return @res;
}

sub calculateThresHold {
	#THE IDEA WOULD BE TO LEARN THE THRESHOLD USING A ML TECHNIQUE
	my $nl = shift ();
	my $nlv = shift();
	return ($nl/$nlv)*0.4281;
}

sub round {
	my $num = shift();
	return int ($num+0.5);
}

sub between {
	my $arg = shift();
	my $min = round(shift());
	my $max = round(shift());
	if (($arg <= $max) && ($min <= $arg)) {
		return 1;
	}
	else {
		return 0;
	}
}


sub mean {
	my @vect = @{shift()};
	my $size = shift();
	$size = 0;
	if (scalar(@vect) == 0) {
		return 0;
	}
	my $sum = 0;
	foreach my $el (@vect) {
		if ($el != 0) {
			$sum += $el;
			$size++;
		}
	}
	return $sum/$size;
}

sub sum {
	my @vect = @{shift()};
	my $sum = 0;
	foreach my $el (@vect) {
		$sum += $el;
	}
	return $sum;
}

sub stdev{
	my @vect = @{shift()};
	my $size = shift();
    my $average = mean (\@vect, scalar(@vect)-1);
    my $sqtotal = 0;
	for (my $i=1; $i<scalar(@vect); $i++) {
       $sqtotal += ($vect[$i] - $average) ** 2;
    }
    my $std = ($sqtotal / $size) ** 0.5;
    return $std;
}
