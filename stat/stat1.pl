#!/usr/bin/perl
# statistika podle logu EZS ve tvaru> 
# Mon May 26 04:53:01 2014,1401072781,user000010
# Mon May 26 04:54:51 2014,1401072891,user000100
# Mon May 26 05:54:41 2014,1401076481,user000001

open(FILENAME,"<ezs.log");
while ( <FILENAME> )
{
  chomp;
  next if /^#/;
  push @filename, [ split /,/ ];
}
close(FILENAME);
$starejklic = 0;

# v elementu [0] hledej prvni tri slova. Ty hledej v dalsi iteraci, dokud se nezmeni
foreach $row (0..@filename-1){
	$datumovka = $filename[$row][0];
	($dweek, $month, $date, $time, $year)  = split(' ',$datumovka);
	$uxtime = $filename[$row][1];
	$ID = $filename[$row][2];
	$klic = $month." ".$date;
	if ($klic ne $starejklic && $starejklic){
		$count_f=0;
		foreach $f ( keys %denni_pole ) {
 		    print "$starejklic: $f: @{ $denni_pole{$f} }\n";
		    $count_f++;
 		}
		print "Za den $starejklic zpracovano $count_f uzivatelu\n";
		undef %denni_pole;
	}
	push @{ $denni_pole{$ID} }, $uxtime;
	$starejklic = $klic;
}

