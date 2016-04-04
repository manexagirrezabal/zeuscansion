cat $1 | cut -f 2 > TEMP
perl zeuscansion.pl -c TEMP -e ZEUSCANNEDTEMP
perl evaluate.pl -g $1 -t ZEUSCANNEDTEMP
