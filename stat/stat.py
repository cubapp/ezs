#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
stat3.py – přepis původního Perl skriptu stat3.pl
Statistika odpracovaných hodin z logu přístupového systému EZS.

Původní Perl skript běží stabilně 12 let.
Tento Python přepis:
- používá POUZE standardní knihovnu Pythonu 3
- zachovává přesně stejnou business logiku
- má opravené zpracování posledního dne (v Perlu chybělo)
- je napsán tak, aby se nemusel měnit při budoucích verzích Pythonu

Autor přepisu: Grok (xAI)
Datum: 2026
"""

from collections import defaultdict
import sys

# ==============================================================================
# KONSTANTY – stejné hodnoty jako v původním Perl skriptu
# ==============================================================================

# $DELTA v Perlu – maximální povolený rozdíl v sekundách mezi dvěma stisky,
# který ještě považujeme za dvojklik / omyl. Novější stisk se ponechá, starší se zahodí.
DELTA = 5

# $MONTAZ v Perlu – pokud je mezi dvěma stisky více než tolik sekund,
# považujeme to za "montáž" (nebo neodhlášení) a později se místo hodin vypíše X.
MONTAZ = 18000   # 5 hodin

# Názvy souborů – stejné jako v Perlu
ID_FILE = "tabulka-ID.txt"   # mapování userID → skutečné jméno
LOG_FILE = "ezs.log"         # vstupní log z EZS

# DEBUG režim (v Perlu $DEBUG)
DEBUG = False


# ==============================================================================
# Načtení tabulky převodu ID → jméno
# Odpovídá části:
#   open FH, $id_file ...
#   while (<FH>) { my ($key,$value) = split(/,\s?/); $user_tab{$key} = $value; }
# ==============================================================================
def load_user_table(filename: str) -> dict[str, str]:
    """
    Načte soubor tabulka-ID.txt a vytvoří slovník:
        klíč = userID (např. "user000010")
        hodnota = skutečné jméno (např. "Mira")

    Pořadí položek je zachováno (Python 3.7+ dict zachovává insertion order).
    To je důležité, protože výstup se tiskne v pořadí, v jakém jsou uživatelé
    v tabulce (stejně jako values %user_tab v Perlu).

    Vrací: dict[str, str]
    """
    user_tab = {}
    with open(filename, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            # split na maximálně 2 části, aby jméno mohlo obsahovat čárku
            parts = [p.strip() for p in line.split(",", 1)]
            if len(parts) == 2:
                key, value = parts
                user_tab[key] = value
    return user_tab


# ==============================================================================
# Načtení a základní parsování logu
# Odpovídá části:
#   open(FILENAME,"<$real_logfile");
#   while ( <FILENAME> ) { next if /^#/; push @filename, [ split /,/ ]; }
# ==============================================================================
def parse_log(filename: str) -> list[list[str]]:
    """
    Načte celý ezs.log do paměti.
    Přeskočí všechny řádky začínající znakem # (komentáře / #begin).
    Každý platný řádek rozdělí podle čárky na seznam:
        [0] = lidsky čitelný datum+čas  (např. "Wed Sep 30 17:38:34 2026")
        [1] = unix timestamp            (např. "1790782714")
        [2] = userID                    (např. "user000010")

    Vrací: list seznamů (stejná struktura jako @filename v Perlu)
    """
    rows = []
    with open(filename, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 3:
                rows.append(parts)
    return rows


# ==============================================================================
# Čištění dvojkliků / omylných stisků
# Odpovídá cyklu uvnitř zpracuj_den_uzivatele:
#   foreach my $uxt (...) {
#       my $rozdil = $uxt - $uxnula;
#       if ($rozdil < $DELTA) { ... } else { push @novepole, $uxt; }
#       $uxnula = $uxt;
#   }
# ==============================================================================
def clean_double_clicks(times: list[int]) -> list[int]:
    """
    Projde seřazený seznam unix timestampů jednoho uživatele za jeden den
    a odstraní dvojkliky.

    Pravidlo (stejné jako v Perlu):
    - Pokud je rozdíl mezi aktuálním a předchozím stiskem < DELTA sekund,
      zahodí se STARŠÍ stisk a ponechá se NOVĚJŠÍ.
    - První stisk se vždy ponechá (protože začínáme s prev = 0).

    Vstup:  list unix timestampů (už seřazených chronologicky)
    Výstup: vyčištěný list unix timestampů
    """
    if not times:
        return []

    cleaned = []
    prev = 0
    for t in times:
        if t - prev >= DELTA:
            cleaned.append(t)
        # else: záměrně nic nepřidáváme → starší stisk zmizí
        prev = t
    return cleaned


# ==============================================================================
# Výpočet odpracovaných minut
# Přesný přepis sub pocitej_odpracovane()
# ==============================================================================
def calculate_worked_minutes(user: str, times: list[int]) -> int:
    """
    Vypočítá odpracované minuty pro jednoho uživatele za jeden den.

    Postup (1:1 podle Perlu):
    1. Pokud je počet stisků sudý → odstraníme POSLEDNÍ prvek
       (považujeme ho za "odchod domů").
    2. VŽDY odstraníme PRVNÍ prvek
       (považujeme ho za "příchod ráno do šatny").
    3. Zbylé stisky bereme po dvojicích (tick1, tick2):
       - spočítáme rozdíl v sekundách
       - pokud je rozdíl > MONTAZ, přičteme navíc 100000 sekund
         (tím pádem později hours > 24 → vypíše se X)
    4. Součet sekund vydělíme 60 a vezmeme celou část (int).

    Vrací: počet minut jako int (stejně jako $suma_minut v Perlu)
    """
    pole = times[:]          # pracujeme s kopií, ať neovlivníme originál
    length = len(pole)

    # Krok 1: při sudém počtu odstranit poslední prvek (odchod domů)
    if length % 2 == 0 and length > 0:
        pole.pop()

    # Krok 2: vždy odstranit první prvek (příchod do šatny)
    if pole:
        pole.pop(0)

    # Krok 3: sčítání párů
    suma_sekund = 0
    i = 0
    while i < len(pole):
        tick1 = pole[i]
        i += 1
        if i >= len(pole):
            break
        tick2 = pole[i]
        i += 1

        diff = tick2 - tick1
        if diff > MONTAZ:
            # Stejně jako v Perlu: $rozdil += 100000;
            diff += 100000
        suma_sekund += diff

    # Krok 4: převod na minuty (celé číslo)
    return suma_sekund // 60


# ==============================================================================
# Zpracování jednoho dne
# Přesný přepis sub zpracuj_den_uzivatele()
# ==============================================================================
def process_day(day_key: str,
                year: str,
                denni_pole: dict,
                user_tab: dict,
                denni_stat: dict) -> None:
    """
    Zpracuje všechna data jednoho kalendářního dne.

    Pro každého uživatele, který ten den stiskl tlačítko:
    1. Vyčistí dvojkliky (clean_double_clicks)
    2. Zaznamená diagnostiku (málo vstupů / lichý počet) – zatím jen do DEBUG
    3. Spočítá odpracované minuty (calculate_worked_minutes)
    4. Uloží výsledek do denni_stat[jméno] = minuty

    day_key   = řetězec typu "Sep 30" nebo "Oct  1" (stejný formát jako $starejklic)
    year      = rok jako string (např. "2026")
    denni_pole = defaultdict(list)  → user_id → seznam unix timestampů
    user_tab  = mapování ID → jméno
    denni_stat = sem se ukládají výsledky (jméno → minuty)
    """
    if DEBUG:
        print(f"-------------[ Datum {day_key}")

    for user_id, times in denni_pole.items():
        real_user = user_tab.get(user_id, user_id)

        if DEBUG:
            print(f"-------------[ Real User: {real_user} OrigUser: {user_id}")

        # 1. Vyčištění dvojkliků
        cleaned = clean_double_clicks(times)
        count = len(cleaned)

        # 2. Diagnostika (stejné podmínky jako v Perlu)
        stav = ""
        if count < 3:
            stav = f"malo vstupu - {count}"
        elif count % 2 != 0:
            stav = f"lichy vstup - {count}"

        if DEBUG:
            print(f"AFTER {day_key}: {user_id}: {real_user}: {count}  RET: {stav} : {cleaned}")

        # 3. Výpočet minut (provádí se VŽDY, i při chybě – stejně jako v Perlu)
        minutes = calculate_worked_minutes(real_user, cleaned)
        denni_stat[real_user] = minutes

        if DEBUG:
            hours = minutes / 60
            print(f"Celkem {real_user} namakal {minutes} min, tj. {hours:.2f} hodin")


# ==============================================================================
# Hlavní program
# Odpovídá hlavnímu cyklu foreach my $row (0..@filename) + finálnímu zpracování
# ==============================================================================
def main():
    """
    Hlavní řídicí funkce.

    Postup:
    1. Načte tabulku ID → jméno
    2. Načte celý log
    3. Prochází záznamy chronologicky a seskupuje je podle dne (month + date)
    4. Při změně dne zavolá process_day() a vytiskne řádek CSV
    5. Po skončení cyklu zpracuje ještě POSLEDNÍ den
       (toto v původním Perl skriptu chybělo → poslední den se nikdy nevypisoval)
    """
    user_tab = load_user_table(ID_FILE)
    rows = parse_log(LOG_FILE)

    if DEBUG:
        print(f"-------[ DEBUG hash {dict(user_tab)}")

    # Hlavička výstupu (stejná jako v Perlu)
    print("Datum,uzivatel,hodiny,uzivatel,hodiny,uzivatel,hodiny,")

    # denni_pole: user_id → seznam unix timestampů daného dne
    denni_pole = defaultdict(list)
    starejklic = None          # předchozí denní klíč ("Sep 30")
    current_year = ""
    denni_stat = {}            # jméno → minuty za aktuální den

    for row in rows:
        datumovka = row[0]           # "Wed Sep 30 17:38:34 2026"
        uxtime = int(row[1])
        user_id = row[2]

        # Rozparsování lidsky čitelného data
        parts = datumovka.split()
        if len(parts) < 5:
            continue

        # parts: [0]=den_v_tydnu, [1]=měsíc, [2]=den, [3]=čas, [4]=rok
        month = parts[1]
        date = parts[2]
        year = parts[4]
        klic = f"{month} {date}"     # stejný formát jako $klic v Perlu
        current_year = year

        # Změna dne → zpracujeme předchozí den a vytiskneme výsledek
        if starejklic is not None and klic != starejklic:
            process_day(starejklic, current_year, denni_pole, user_tab, denni_stat)

            # Tisk řádku (stejný formát jako v Perlu)
            print(f"{current_year} {starejklic}", end="")
            for name in user_tab.values():
                if "test" in name.lower():
                    continue
                minutes = denni_stat.get(name, 0)
                hours = minutes / 60.0
                if hours > 24:
                    print(f",{name},X", end="")
                else:
                    print(f",{name},{hours:.2f}", end="")
            print()

            # Reset pro nový den
            denni_pole = defaultdict(list)
            denni_stat = {}

        # Přidání aktuálního stisku
        denni_pole[user_id].append(uxtime)
        starejklic = klic

    # --------------------------------------------------------------------------
    # Zpracování POSLEDNÍHO dne
    # V původním Perl skriptu tato část chyběla – poslední den se nikdy nevypisoval.
    # --------------------------------------------------------------------------
    if starejklic is not None:
        process_day(starejklic, current_year, denni_pole, user_tab, denni_stat)

        print(f"{current_year} {starejklic}", end="")
        for name in user_tab.values():
            if "test" in name.lower():
                continue
            minutes = denni_stat.get(name, 0)
            hours = minutes / 60.0
            if hours > 24:
                print(f",{name},X", end="")
            else:
                print(f",{name},{hours:.2f}", end="")
        print()


# ==============================================================================
# Spuštění
# ==============================================================================
if __name__ == "__main__":
    main()
