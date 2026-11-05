# Statistiky odpracovaných hodin z EZS logu

Přepis původního Perl skriptu stat3.pl do čistého Pythonu 3.

Skript zpracovává log přístupového systému (EZS), kde každý pracovník má vlastní tlačítko.  
Záznamy stisků se používají k výpočtu odpracované doby za den (včetně ošetření dvojkliků, lichých počtů stisků a „montáží“).

Původní Perl verze běží stabilně již 12 let.  
Tento Python přepis zachovává přesně stejnou business logiku a je napsán tak, aby vydržel stejně dlouho.

## Požadavky

- Python 3.6+ (testováno na 3.13.5)
- Žádné externí knihovny – pouze standardní knihovna Pythonu

## Soubory

Soubor              | Popis
--------------------|------------------------------------------
stat3.py            | Hlavní program
tabulka-ID.txt      | Mapování userID → jméno
ezs.log             | Vstupní log z EZS

### Formát tabulka-ID.txt
```
user000010,Mia
user000100,Paik
user000001,Mial
...
```

### Formát ezs.log
```
Wed Sep 30 17:38:34 2026,1790782714,user000010
Wed Sep 30 17:38:41 2026,1790782721,user000100
...
#begin ...          ← tyto řádky se ignorují
```


## Spuštění

`python3 stat3.py`

Výstup jde na standardní výstup ve stejném formátu jako původní Perl skript:


```
Datum,uzivatel,hodiny,uzivatel,hodiny,uzivatel,hodiny,
2026 Sep 30 ,Mia,X,Paik,0.00,Mial,X
2026 Oct 1 ,Mia,X,Paik,0.00,Mial,X
...
```

## Hlavní logika (shodná s Perlem)

1. Dvojklik / omyl (DELTA = 5 s)  
   Pokud jsou dva stisky blíže než 5 sekund, ponechá se novější, starší se zahodí.

2. Málo stisků (< 3)  
   Den se považuje za nehodnotitelný (obvykle 0.00).

3. Lichý počet stisků  
   Označí se jako problematický, ale výpočet se stejně provede („základní odečet“).

4. Výpočet času
   - Odstraní se první stisk (příchod do šatny)
   - Při sudém počtu se odstraní i poslední stisk (odchod domů)
   - Zbylé stisky se berou po dvojicích a sčítají se rozdíly
   - Pokud je rozdíl > MONTAZ (5 hodin) → přičte se 100 000 s → později se vypíše X

5. Výstup
   - Hodiny s přesností na 2 desetinná místa
   - Pokud > 24 hodin → X (montáž / neodhlášení)

## Opravy oproti původnímu Perlu

- Poslední den se nyní zpracovává  
  V původním skriptu chybělo finální volání zpracuj_den_uzivatele() po skončení cyklu.

## Autor

Přepis z Perlu do Pythonu: Grok (xAI)  
Původní autor Perl skriptu: (Jakub Urbanec)

## Licence

(za rum od Pepika)
