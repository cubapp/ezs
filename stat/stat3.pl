#!/usr/bin/perl                                                                                                                                                                                          [0/611]
use strict;
use warnings;

# statistika podle logu EZS ve tvaru>
# Mon May 26 04:53:01 2014,1401072781,user000010
# Mon May 26 04:54:51 2014,1401072891,user000100
# Mon May 26 05:54:41 2014,1401076481,user000001

# Definice konstant
# $DELTA = udava cas v sekundach mezi stisknutim tlacitka,
#          kdy je povazovano za chybu nebo dvakrat klik
my $DELTA = 5;

# $MONTAZ = cas v sekundach. Jestli je od stisknuti tlacitek
#               $MONTAZ cas, pak se jelo na montaz a misto hodin znacim 'X'
my $MONTAZ= 18000;

# Tabulka prevodu ID na jmeno
my $id_file = "tabulka-ID.txt";

# skutecny logfile z EZSky
my $real_logfile = "ezs.log";

# DEBUG
#my $DEBUG = 1;
my $DEBUG = 0;


### DEFINICE Promennych
# Hash array %user_tab
# ID,real_user_name
my %user_tab;
my $starejklic = 0;
my %denni_stat;
my %denni_pole;
my @filename;
my $id;

#inicializace vice promennych
my ($dweek, $month, $date, $time, $year)  = '' x 5;

open FH, $id_file or die $!;
while (<FH>) {
    chomp;
    my ($key,$value) = split(/,\s?/);    # '?' makes space optional.
    $user_tab{$key} = $value;
}
close FH;

print "-------[ DEBUG hash @{[ %user_tab ]}\n" if $DEBUG;

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


print "Datum,uzivatel,hodiny,uzivatel,hodiny,uzivatel,hodiny,\n";

# v elementu [0] hledej prvni tri slova. ty hledej v dalsi iteraci, dokud se nezmeni
#foreach $row (0..@filename-1){
foreach my $row (0..@filename){
        my $datumovka = '';
        $datumovka = $filename[$row][0];
        if ($datumovka) { ($dweek, $month, $date, $time, $year)  = split(' ',$datumovka); }
        my $uxtime = $filename[$row][1];
        $id = $filename[$row][2];
        my $klic = $month." ".$date;
        if ($klic ne $starejklic && $starejklic){
                &zpracuj_den_uzivatele();
                %denni_pole = ();
        }
        if ($id) {push @{ $denni_pole{$id} }, $uxtime;}
        $starejklic = $klic;
}


#print "Datum,|,uzivatel,minuty,hodiny,|,uzivatel,minuty,hodiny,|,uzivatel,minuty,hodiny,|,uzivatel,minuty,hodiny,|,uzivatel,minuty,hodiny,|,uzivatel,minuty,hodiny,\n";

# je treba vyhodnotit>
## 1. jestli pocet stisku tlacitka je lichy, pak hlasi problem a udelat zakladni odecet
## 2. jestli je pocet stisku tlacitka mensi nez 3, pak nelze hodnotit
## 3. jeslit je rozdil mezi stisky mensi nez $DELTA (10s) pak druhou hodnotu smazat
# pro 1 den 1 usera potrebuju
# - ID, odecet casu, identifikaci_OK


sub zpracuj_den_uzivatele ()
{
        my @novepole;
        my $dnesni_datum = $starejklic;
        my $count_user = 0;
        print "-------------[ Datum $dnesni_datum \n" if $DEBUG;
        foreach my $user ( keys %denni_pole ) {
                undef @novepole ;
                my $real_user = $user_tab{$user};
                print "-------------[ Real User: $real_user OrigUser: $user \n" if $DEBUG;
                my $stav = 0;
                my $pocetmu = scalar @{ $denni_pole{$user}};
                print "-------------[ PocetMU $pocetmu uzivatele: $user \n" if $DEBUG;
                my $pocetmu_predsanaci = $pocetmu;
                my $uxnula = 0;
                print "BEFORE $dnesni_datum: $user: $pocetmu ZAZN. : @{ $denni_pole{$user} }\n" if $DEBUG;
                foreach my $uxt (values @{$denni_pole{$user}}){
                        my $rozdil = $uxt - $uxnula;
                        if ($rozdil < $DELTA){
                                print "MAZAME $user: puvodne $uxnula - necham $uxt\n" if $DEBUG;
                        }
                        else {
                                push @novepole, $uxt;
                        }
                        $uxnula = $uxt;
                }
                my $pocetmu2= scalar @novepole;

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
        print "-------------[ Za datum $dnesni_datum zpracovano $count_user uzivatelu\n" if $DEBUG;

# Tiskneme vystup

        print "$year $dnesni_datum ";
        foreach my $uziv ( values %user_tab ){
                next if ($uziv =~ /test/);
                my $minut = $denni_stat{$uziv};

                if ( ! $minut ) {
                        $minut = 0 ;
                }
                my $hodin = sprintf "%.2f",$minut/60;
                #print ", ,$uziv,$minut,$hodin";
                if ($hodin > 24) {
                        print ",$uziv,X";
                }
                else {
                        print ",$uziv,$hodin";
                }
        }
        print "\n";

        undef %denni_stat;
}


sub pocitej_odpracovane() {
        my $suma_minut=0;
        my $suma_sekund=0;
        my $suma_hodin=0;
        my $tick1 = 0;
        my $tick2 = 0;
        my $rozdil = 0;
        my ($user, @poleuxt ) = @_;
        my $delka_pole = scalar @poleuxt;
        print "Z procedury pocitej odpracovane o uzivatele $user: ZAZN: $delka_pole : @poleuxt \n" if $DEBUG;
        #remove last element (tj. odchod domu)
        # pouze je-li delka pole suda
        if ($delka_pole % 2 == 0 ){
                my $odmazanej = pop (@poleuxt);
                my $trtr = $delka_pole % 2 ;
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
                        if ($rozdil > $MONTAZ){
                                print "Narazili jsme na MONTAZ: rozdil=$rozdil. Pricitame den" if $DEBUG;
                                $rozdil+=100000;
                        }
                        $suma_sekund += $rozdil;
                }
        }
        $suma_minut = int($suma_sekund/60);
        $suma_hodin = sprintf "%.2f",$suma_minut/60;
        if ($user) { $denni_stat{$user} = $suma_minut;  }
        print "Celkem $user namakal $suma_minut min, tj. $suma_hodin hodin\n" if $DEBUG;
}

