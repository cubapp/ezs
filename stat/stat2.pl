#!/usr/bin/perl
# statistika podle logu EZS ve tvaru> 
# Mon May 26 04:53:01 2014,1401072781,user000010
# Mon May 26 04:54:51 2014,1401072891,user000100
# Mon May 26 05:54:41 2014,1401076481,user000001

# Definice konstant
# $DELTA = udava cas v sekundach mezi stisknutim tlacitka, 
#          kdy je povazovano za chybu nebo dvakrat klik
$DELTA = 5;

# Tabulka prevodu ID na jmeno
$id_file = "tabulka-ID.txt";

# skutecny logfile z EZSky
$real_logfile = "ezs.log";

# DEBUG
#$DEBUG = 1;
$DEBUG = 0;

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
	# radeji zkopirujeme pole 
	for my $k (keys %denni_pole) {
    		$tempole{$k} = [ @{$denni_pole{$k}} ];
	}
	$dnesni_datum = $starejklic;
	$count_user = 0;
	@docasne_pole = ();
	foreach $user ( keys %tempole ) {
		undef @novepole ;
		$real_user = $user_tab{$user};
		$stav = 0;
		$pocetmu= keys $tempole{$user};
		$pocetmu_predsanaci = $pocetmu;	
		$uxnula = 0;
 	    	print "BEFORE $dnesni_datum: $user: $pocetmu ZAZN. : @{ $tempole{$user} }\n" if $DEBUG;
		foreach $uxt (values $tempole{$user}){
			$rozdil = $uxt - $uxnula;
			if ($rozdil < $DELTA){
				print "MAZAME $user: puvodne $uxnula - necham $uxt\n" if $DEBUG;
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
 	    	print "AFTER $dnesni_datum: $user: $real_user: $pocetmu2 ($pocetmu_predsanaci)  ZAZN. RET: $stav : @novepole \n" if $DEBUG;
		&pocitej_odpracovane($real_user, @novepole);
		$count_user++;
 	}
	print "-------------[ Za datum $dnesni_datum zpracovano $count_user uzivatelu\n";
        undef %tempole;
}

sub pocitej_odpracovane() {
	($user, @poleuxt ) = @_;
	$delka_pole = scalar @poleuxt;
	print "Z procedury pocitej odpracovane o uzivatele $user: ZAZN: $delka_pole : @poleuxt \n" if $DEBUG;
	#remove last element (tj. odchod domu)
	# pouze je-li delka pole suda
	if ($delka_pole % 2 == 0 ){
		$odmazanej = pop (@poleuxt);
		$trtr = $delka_pole % 2 ;
		print "DEBUG: Odmazal jsem prvek: $odmazanej z pole delky $delka_pole. Test: $trtr \n" if $DEBUG;
	};
	#remove first element (tj. prijdu rano do saten)
	shift (@poleuxt);
	$delka_pole = scalar @poleuxt;
	print "R procedury pocitej odpracovane o uzivatele $user: ZAZN: $delka_pole : @poleuxt \n" if $DEBUG;
	
	$suma_sekund = 0;
	for(my $i=0; $i < @poleuxt; $i++) {
		$tick1 = $poleuxt[$i];
		$i++;
		$tick2 = $poleuxt[$i];
		if ($tick2) {
			$rozdil = $tick2 - $tick1;
			print "Rozdil mezi $tick2 a $tick1 = $rozdil \n" if $DEBUG;
			$suma_sekund += $rozdil;
		}
	}
	$suma_minut = $suma_sekund/60;
	$suma_hodin = $suma_minut/60;
	print "Celkem $user namakal $suma_sekund s, tj. $suma_minut min, tj $suma_hodin h\n";
}
