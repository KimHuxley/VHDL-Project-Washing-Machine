----------------------------------------------------------------------------------
-- Autor: Wiktor Krywult
-- Numer indeksu: 275592
-- Projekt: Sterownik zmywarki
-- Grupa: pt 15:45
-- Data: 8.01.2026
----------------------------------------------------------------------------------
library IEEE;						-- zalaczenie biblioteki
use IEEE.STD_LOGIC_1164.ALL;	-- zalaczenie pakietu


entity utt is			-- Deklaracja ukadu wejscia i wyjscia
	Port(	
			-- WEJSCIA --
			-- syganly sterujace i zegarowe
			CLK					: in STD_LOGIC; 							-- zegar systemowy
			RESET					: in STD_LOGIC; 							-- reset asynchroniczny
			START					: in STD_LOGIC; 							-- przycisk start
			
			-- Sygnaly z czujnikow
			DOOR_OPEN			: in STD_LOGIC; 							-- czujnik otwarcia drzwi
			AWARIA_ZASILANIA	: in STD_LOGIC; 							-- symulacja awarii przy braku pradu
			TRYB_PRACY			: in STD_LOGIC_vector (1 downto 0); -- wybor programu
			
			-- WYJSCIA (elementy wykonawcze)--
			Zawor_Wody			: out STD_LOGIC;							-- sterowanie doplywem wody
			Pompa_Odplyw		: out STD_LOGIC;							--	sterowanie odplywem wody
			Pompa_Myjaca		: out STD_LOGIC;							-- sterowanie pompa myjaca
			Grzalka				: out STD_LOGIC;							-- sterowanie grzalka
			Dozownik				: out STD_LOGIC;							-- sterowanie dozownikiem
			
			-- WYJSCIE DIAGNOSTYCZNE (podglad stanow)--
			stan					: out STD_LOGIC_VECTOR(3 downto 0)
	);
end utt;

architecture Behavioral of utt is
	-- DEFINICJA STANOW --
	type State_type is (
		BEZCZYNNY,
		WYPELNIANIE,
		MYCIE_WSTEPNE,
		DOZOWANIE,
		ODPOMPOWANIE,
		PLUKANIE,
		SUSZENIE,
		KONIEC,
		ALARM,				-- Stan po otwarciu drzwi 
		BRAK_ZASILANIA,	-- Stan brak zasilania oczekiwanie na powrot lub do awarii krytycznej 
		AWARIA_KRYTYCZNA	-- stan po przekroczeniu limitu zasilania 
	);
	
	-- SYGNALY WEWNETRZNE --
	--Rejestry stanow 
	signal obecny_stan    : State_Type := BEZCZYNNY;
	signal poprzedni_stan : State_Type := BEZCZYNNY;	-- rejestr pamieci do wznowienia pracy 
	
	-- liczniki i limit
	signal licznik_czasu  : integer := 0;
	signal licznik_awarii : integer := 0;		--licznik czasu trwania braku zasilania 
	signal limit_czasu	 : integer := 100;	--zmienna dynamiczna (zalezna od trybu pracy)
	
	-- LIMIT AWARII --
	constant LIMIT_AWARII : integer := 50;		--limit cykli zegara dla braku zasilania 
	
	-- CZASY DLA MYCIA GLOWNEGO --
	constant T_MYCIE_ECO			: integer := 30;
	constant T_MYCIE_STD			: integer := 20;
	constant T_MYCIE_TURBO		: integer := 10;
	
	-- CZASY SUSZENIA --
	constant T_SUSZENIE_ECO	: integer := 5;
	constant T_SUSZENIE_STD	: integer := 12;
	constant T_SUSZENIE_TURBO	: integer := 10;
	
	-- CZASY STALE --
	constant T_WYPELNIENIE	: integer := 15;
	constant T_WSTEPNE		: integer := 20;
	constant T_ODPOMPOWANIE : integer := 15;
	constant T_PLUKANIE		: integer := 20;
	
begin

	-- GLOWNY PROCES STERUJACY --
	Sterowanie_Zmywarka : process(CLK, RESET)
	begin 
		-- RESET asynchroniczny	: (najwyzszy priorytet)--
		if RESET = '1' then
			obecny_stan <= BEZCZYNNY;
			licznik_czasu <= 0;
			licznik_awarii<= 0;
			
			-- wylaczenie wszystkich wyjsc --
			Zawor_Wody <= '0';
			Pompa_Odplyw <= '0';
			Pompa_Myjaca <= '0';
			Grzalka <= '0';
			Dozownik <= '0';
			stan <= "0000";
		
		-- synchronizacja : dla zobcza narastajacego --
		elsif CLK'event and CLK = '1' then
		
		-- OBSLUGA BRAKU ZASILANIA : (wyzszy priorytet niz normalna praca)--
			if AWARIA_ZASILANIA = '1' then		
				
				-- scenariusz A: awaria juz trwa _ 2 etap
				if obecny_stan = BRAK_ZASILANIA then		
					stan <= "1100";
					-- wymuszenie stanu bezpieczenstwa : wylaczenie wszystkiego --
					Zawor_Wody <= '0'; 
					Pompa_Myjaca <= '0'; 
					Grzalka <= '0'; 
					Pompa_Odplyw <= '0';
					Dozownik <= '0';
					
					-- zliczenie czasu awarii	
					licznik_awarii <= licznik_awarii +1;
					
						--sprawdzenie czy przekroczono limit _ 3. etap (jesli przekroczy limit)
						if licznik_awarii > LIMIT_AWARII then
							obecny_stan <= AWARIA_KRYTYCZNA;
						end if;
						
					-- Scenariusz B: przebywanie w AWARIA_KRYTYCZNA do momentu restartu	--
				elsif obecny_stan = AWARIA_KRYTYCZNA then
					stan <= "1110";
					
			-- Scenariusz C: Moment wystapienia awarii, pierwszy cykl - 1 etap
			else													
				poprzedni_stan <= obecny_stan;	--zapamietanie stanu
				obecny_stan <= BRAK_ZASILANIA;
				licznik_awarii <= 0;
					
				-- wylaczenie wszystkich wyjsc --
				Zawor_Wody <= '0';
				Pompa_Myjaca <= '0';
				Grzalka <= '0';
				Pompa_Odplyw <= '0';
				Dozownik <= '0';
			end if;
				
			-- NORMALNA PRACA -- jest zasilanie
			else 
				-- Sprawdzamy czy własnie prad wrocil (bylismy w BRAK_ZASILANIA) : procedura bezpieczenstwa
				if obecny_stan = AWARIA_KRYTYCZNA then
					stan <= "1110";
					Pompa_Odplyw <= '1';	-- wypompowanie wody
					
				-- Sprawdzamy powrotu z krotkiej awarii zasilania : (wznowienie pracy)
				elsif obecny_stan = BRAK_ZASILANIA then
					obecny_stan <= poprzedni_stan;	-- powrot do stanu
					
				else

				-- logika maszyny stanow --
				case obecny_stan is
				
					when BEZCZYNNY =>
						stan <= "0001";
						licznik_czasu <= 0;
						
						--wylaczenie wszystkiego 
						Zawor_Wody <= '0';
						Pompa_Myjaca <= '0';
						Grzalka <= '0';
						
						if START = '1' then
							if DOOR_OPEN = '1' then
								--blokada przy otwarciu drzwi --
								poprzedni_Stan <= BEZCZYNNY;
								obecny_stan <= ALARM;
							else
								obecny_stan <= WYPELNIANIE;
							end if;
						end if;
						
						when WYPELNIANIE =>
							stan <= "0010";
							Zawor_Wody <= '1';
							
							licznik_czasu <= licznik_czasu + 1;
							if licznik_czasu >= T_WYPELNIENIE then
								licznik_czasu <= 0;
								Zawor_Wody <= '0';
								obecny_stan <= MYCIE_WSTEPNE;
							end if;
							
						when MYCIE_WSTEPNE =>
							stan <= "0011";
							Pompa_Myjaca <= '1';
							
							licznik_czasu <= licznik_czasu + 1;
							if licznik_czasu >= T_WSTEPNE then
								licznik_czasu <= 0;
								Pompa_myjaca <= '0';
								obecny_stan <= DOZOWANIE;
							end if;
							
						when DOZOWANIE =>
							stan <= "0100";
							Dozownik <= '1';
							Pompa_myjaca <= '1';
							Grzalka <= '1';
						
							--WYBOR CZASU PRACU--
							if TRYB_PRACY = "00" then
								limit_czasu <= T_MYCIE_ECO;
							elsif TRYB_PRACY = "01" then
								limit_czasu <= T_MYCIE_STD;
							else
								limit_czasu <= T_MYCIE_TURBO;
							end if;
							
							licznik_czasu <= licznik_czasu +1;
							if licznik_czasu >= limit_czasu then
								licznik_czasu <= 0;
								Dozownik <= '0';
								Pompa_Myjaca <= '0';
								Grzalka <= '0';
								obecny_stan <= ODPOMPOWANIE;
							end if;
						
						when ODPOMPOWANIE =>
							stan <= "0101";
							Pompa_Odplyw <= '1';
							
							licznik_czasu <= licznik_czasu + 1;
							if licznik_czasu >= T_ODPOMPOWANIE then
								licznik_czasu <= 0;
								Pompa_Odplyw <= '0';
								obecny_stan <= PLUKANIE;
							end if;
							
						when PLUKANIE =>
							stan <= "0110";
							Zawor_Wody <= '1';
							Pompa_myjaca <= '1';
								
							licznik_czasu <= licznik_czasu + 1;
							if licznik_czasu >= T_PLUKANIE then
									licznik_czasu <= 0;
									Zawor_Wody <= '0';
									Pompa_Myjaca <= '0';
									obecny_Stan <= SUSZENIE;
								end if;
								
							when SUSZENIE =>
								stan <= "0111";
								grzalka <= '1';
								
								--WYBOR CZASU PRACU--
								if TRYB_PRACY = "00" then
									limit_czasu <= T_SUSZENIE_ECO;
								elsif TRYB_PRACY = "01" then
									limit_czasu <= T_SUSZENIE_STD;
								else
									limit_czasu <= T_SUSZENIE_TURBO;
								end if;
								
								licznik_czasu <= licznik_czasu + 1;
								if licznik_czasu >= limit_czasu then
									licznik_czasu <=0;
									grzalka <= '0';
									obecny_stan <= KONIEC;
								end if;
								
							when KONIEC =>
								stan <= "1111";
								-- start nie jest wcisniety
								if START = '0' then
									obecny_stan <= BEZCZYNNY;
								end if;
								
							--STANY SPECJALNE DLA AWARII :  (otwarte drzwu)--
							when ALARM =>
								stan <= "1010";
								-- WSZYTKO STOP--
								Zawor_Wody <= '0';
								Pompa_Myjaca <= '0';
								Grzalka <= '0';
								Pompa_odplyw <= '0';
								
								--powrot pracy przy zamknieciu drzwi --
								if DOOR_OPEN = '0' then
									obecny_stan <= poprzedni_stan;
								end if;
							
							when others =>
								obecny_stan <= BEZCZYNNY;
						end case;
						
						--OBSLUGA OTWARCIA DRZWI--
						if DOOR_OPEN = '1' then
							--SPRAWDZENIE CZY TO STAN GDZIE MOZNA PRZERWAC PRACE
							if obecny_stan = WYPELNIANIE or 
								obecny_stan = MYCIE_WSTEPNE or 
								obecny_stan = DOZOWANIE or 
								obecny_stan = ODPOMPOWANIE or 
								obecny_stan = PLUKANIE or 
								obecny_stan = SUSZENIE then

								poprzedni_stan <= obecny_stan;	--zapamietanie stanu 
								obecny_stan <= ALARM;
							end if;
						end if;
					end if;
				end if;
			end if;
		end process;				

end Behavioral;	
	
