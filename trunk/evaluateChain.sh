cat $1 | cut -f 2 > TEMP
perl process.pl -c TEMP -e ZEUSCANNEDTEMP
perl evaluate.pl -g $1 -t ZEUSCANNEDTEMP
