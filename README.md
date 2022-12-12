## Overview
ZeuScansion is a finite-state technology based system capable of performing metrical scansion of verse written in English. This system is composed of several transducers (compiled using foma) and are put them all together using Perl programming language.

## Requirements
The minimum software requirements for running ZeuScansion are:

  * foma (https://code.google.com/archive/p/foma/)

  * hunpos (https://code.google.com/archive/p/hunpos/) (trained with English Wall Street Journal corpus)
  
## Minimum configuration
The only thing that must be configured is the model for the English POS-tagger. The file location for the model trained using the Hunpos POS-tagger should be specified in the file "zeuscansion.conf". This model file is included in the hunpos repository, and it can be downloaded from this address (https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/hunpos/en_wsj.model.gz).

## Usage
For scanning a poem, we just have to execute zeuscansion with the following parameters. This will give us the meter that ZeuScansion calculates for us:

    `perl zeuscansion.pl -c <POEM-FILE>`

If we add the parameter "-p" we will see the stress assignment process step by step for each word of the poem. The process has four steps, POS-tagging, lexical stress calculation, Groves rules' application and cleanup.

    `perl zeuscansion.pl -c <POEM-FILE> -p`

If we add the parameter "-n" ZeuScansion will show us the average stress value assigned to each syllable from 0 to 1, being 0 unstressed and 1 stressed.

    `perl zeuscansion.pl -c <POEM-FILE> -n`
 
 For this information, just execute ZeuScansion with "-h" parameter to get this information in the terminal.
 
## References:
Agirrezabal, Manex, Bertol Arrieta, Aitzol Astigarraga, and Mans Hulden. "ZeuScansion: a tool for scansion of English poetry." In Proceedings of the 11th International Conference on Finite State Methods and Natural Language Processing, pp. 18-24. 2013.

Manex Agirrezabal, Aitzol Astigarraga, Bertol Arrieta, Mans Hulden (2016), ZeuScansion: A Tool for Scansion of English Poetry, In Journal of Language Modelling (http://jlm.ipipan.waw.pl/index.php/JLM/article/view/102)
