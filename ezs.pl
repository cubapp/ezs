#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw( usleep );
use HiPi::Device::GPIO;
use HiPi::Constant qw( :raspberry );

# procedury jsou pod hlavnim programem
sub pininit;
sub startLED; 

# the pins we are going to use
    my $pinid1 = RPI_PAD1_PIN_21; my $pin1;
    my $pinid2 = RPI_PAD1_PIN_23; my $pin2;
    my $pinid3 = RPI_PAD1_PIN_7;  my $pin3;
    my $pinid4 = RPI_PAD1_PIN_11; my $pin4;
    my $pinid5 = RPI_PAD1_PIN_13; my $pin5;
    my $pinid6 = RPI_PAD1_PIN_15; my $pin6;
    my $dev = HiPi::Device::GPIO->new;

my $date = localtime();
my $bit = 0b000000;
my $str = "";
my $click = 0; 
my $log = "/opt/ezs/log/ezs.log";

# PROGAM:
# inicializace PINu - 6 input, 1 output LED
pininit();     
#start programu LEDky
startLED();

while (1) {
	$str = "0b".$pin1->value().$pin2->value().$pin3->value().$pin4->value().$pin5->value().$pin6->value();
	$bit = oct ($str);
	if ($bit) {
		if (!$click){
			open (LOG, '>>', $log) or die "Can not open logfile $log";
			$date = localtime();
			print "$date,"; print time; 
			print LOG "$date,"; print LOG time;
			printf ",user%06b\n",$bit;
			printf LOG ",user%06b\n",$bit;
		 	#system ("/usr/bin/aplay -q b2.wav");	
		 	system ("/usr/bin/aplay -q /opt/ezs/b1.wav");	
			usleep (30000);			
			close (LOG);
		}
		$click = 1; 
	}
	else {
		$click = 0;
	}
	usleep (10000);			
}

#################
# pininit() 
#  inicializuje PINy GPIO

sub pininit(){

    system ("/usr/local/bin/gpio reset");
    $dev->export_pin($pinid1);
    $dev->export_pin($pinid2);
    $dev->export_pin($pinid3);
    $dev->export_pin($pinid4);
    $dev->export_pin($pinid5);
    $dev->export_pin($pinid6);
    $pin1 = $dev->get_pin($pinid1); $pin1->mode(RPI_PINMODE_INPT);
    $pin2 = $dev->get_pin($pinid2); $pin2->mode(RPI_PINMODE_INPT);
    $pin3 = $dev->get_pin($pinid3); $pin3->mode(RPI_PINMODE_INPT);
    $pin4 = $dev->get_pin($pinid4); $pin4->mode(RPI_PINMODE_INPT);
    $pin5 = $dev->get_pin($pinid5); $pin5->mode(RPI_PINMODE_INPT);
    $pin6 = $dev->get_pin($pinid6); $pin6->mode(RPI_PINMODE_INPT);
}

sub startLED() {
        print "$date: zaciname ";
	system ("/usr/bin/aplay -q /opt/ezs/hallelujah.wav");
        print "ted\n";
	system ("/usr/bin/aplay -q /opt/ezs/b2.wav");
	open (LOG, '>>', $log) or die "Can not open logfile $log";
        $date = localtime();	
	print LOG "#begin $date\n";
	close LOG;
}
