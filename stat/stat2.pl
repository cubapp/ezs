#!/usr/bin/perl
# statistika podle logu EZS ve tvaru> 
# Mon May 26 04:53:01 2014,1401072781,user000010
# Mon May 26 04:54:51 2014,1401072891,user000100
# Mon May 26 05:54:41 2014,1401076481,user000001

# Definice konstant
# $DELTA = udava cas v sekundach mezi stisknutim tlacitka, 
#          kdy je povazovano za chybu nebo dvakrat klik
$DELTA = 11;

# Tabulka prevodu ID na jmeno
$id_file = "tabulka-ID.txt";

# skutecny logfile z EZSky
$real_logfile = "ezs.log";

#Hash array %user_tab
# ID,real_user_name
my %user_tab;
open FH, $id_file or die $!;
while (<FH>) {
    chomp;    
    my ($key,$value) = split(/,\s?/);    # '?' makes space optional.
    $user_tab{$key} = $value;
}
close FH;

# Array of hashes for data from ezs log 
# 
open(FILENAME,"<$real_logfile");
while ( <FILENAME> )
{
  chomp;
  next if /^#/;
  push @filename, [ split /,/ ];
}
close(FILENAME);

$starejklic = 0;

# v elementu [0] hledej prvni tri slova. Ty hledej v dalsi iteraci, dokud se nezmeni
#foreach $row (0..@filename-1){
foreach $row (0..@filename){
	$datumovka = $filename[$row][0];
	($dweek, $month, $date, $time, $year)  = split(' ',$datumovka);
	$uxtime = $filename[$row][1];
	$ID = $filename[$row][2];
	$klic = $month." ".$date;
	if ($klic ne $starejklic && $starejklic){
		&zpracuj_den_uzivatele();
		%denni_pole = ();
	}
	push @{ $denni_pole{$ID} }, $uxtime;
	$starejklic = $klic;
}

# je treba vyhodnotit>
## 1. jestli pocet stisku tlacitka je lichy, pak hlasi problem a udelat zakladni odecet
## 2. jestli je pocet stisku tlacitka mensi nez 3, pak nelze hodnotit
## 3. jeslit je rozdil mezi stisky mensi nez $DELTA (10s) pak druhou hodnotu smazat
# pro 1 den 1 usera potrebuju
# - ID, odecet casu, identifikaci_OK


sub zpracuj_den_uzivatele ()
{
	for my $k (keys %denni_pole) {
    		$tempole{$k} = [ @{$denni_pole{$k}} ];
	}
	$dnesni_datum = $starejklic;
	$count_user = 0;
	@docasne_pole = ();
	foreach $user ( keys %tempole ) {
		undef @novepole ;
		$stav = 0;
		$pocetmu= keys $tempole{$user};
		$pocetmu_predsanaci = $pocetmu;	
		$uxnula = 0;
 	    	print "BEFORE $dnesni_datum: $user: $pocetmu ZAZN. : @{ $tempole{$user} }\n";
		foreach $uxt (values $tempole{$user}){
			$rozdil = $uxt - $uxnula;
			if ($rozdil < $DELTA){
				print "MAZAME $user: puvodne $uxnula - necham $uxt\n";
			}
			else {
				push @novepole, $uxt; 
			}
			$uxnula = $uxt;
		}
		$pocetmu2= scalar @novepole;

		# Sanace problemovych vstupu:
                if ($pocetmu2 < 3) {
                        $stav = "malo vstupu - " . $pocetmu2;
                }
                elsif ( 0 != $pocetmu2 % 2){
                        $stav = "lichy vstup - " . $pocetmu2;
                }

 	    	print "AFTER $dnesni_datum: $user: $user_tab{$user}: $pocetmu2 ($pocetmu_predsanaci)  ZAZN. RET: $stav : @novepole \n";
		$count_user++;
 	}
	print "--------------[ Za datum $dnesni_datum zpracovano $count_user uzivatelu\n";
        undef %tempole;
}
