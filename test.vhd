----------------------------------------------------------------------------------
-- Autor: Wiktor Krywult
-- Numer indeksu: 275592
-- Projekt: Sterownik zmywarki - test
-- Grupa: pt 15:45
-- Data: 8.01.2026
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY test IS
END test;
 
ARCHITECTURE behavior OF test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT utt
    PORT(
         CLK : IN  std_logic;
         RESET : IN  std_logic;
         START : IN  std_logic;
         DOOR_OPEN : IN  std_logic;
         TRYB_PRACY : IN  std_logic_vector(1 downto 0);
         AWARIA_ZASILANIA : IN  std_logic;
         Zawor_Wody : OUT  std_logic;
         Pompa_odplyw : OUT  std_logic;
         Pompa_myjaca : OUT  std_logic;
         grzalka : OUT  std_logic;
         dozownik : OUT  std_logic;
         stan : OUT  std_logic_vector(3 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RESET : std_logic := '0';
   signal START : std_logic := '0';
   signal DOOR_OPEN : std_logic := '0';
   signal TRYB_PRACY : std_logic_vector(1 downto 0) := (others => '0');
   signal AWARIA_ZASILANIA : std_logic := '0';

 	--Outputs
   signal Zawor_Wody : std_logic;
   signal Pompa_odplyw : std_logic;
   signal Pompa_myjaca : std_logic;
   signal grzalka : std_logic;
   signal dozownik : std_logic;
   signal stan : std_logic_vector(3 downto 0);

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut_instant: utt PORT MAP (
          CLK => CLK,
          RESET => RESET,
          START => START,
          DOOR_OPEN => DOOR_OPEN,
          TRYB_PRACY => TRYB_PRACY,
          AWARIA_ZASILANIA => AWARIA_ZASILANIA,
          Zawor_Wody => Zawor_Wody,
          Pompa_odplyw => Pompa_odplyw,
          Pompa_myjaca => Pompa_myjaca,
          grzalka => grzalka,
          dozownik => dozownik,
          stan => stan
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
		--RESET--
		RESET <= '1';
		DOOR_OPEN <= '1'; --otwarte drzwi 
		wait for 100ns;
		RESET <= '0';
		wait for CLK_period*10;
		
		--TEST 1. PELNY CYKL STANDAROWE MYCIE--
		DOOR_OPEN <= '0';
		wait for CLK_period*5;
		
		TRYB_PRACY  <= "01";	-- ustawienie trybu STANDARD
		START <= '1';			--klikamy start 
		wait for CLK_period*2;
		START <= '0';			--puszczamy
		
		wait for CLK_period *30;
		
		DOOR_OPEN <= '1'; --OTWIERAMY drzwi by sprawdzic co sie stanie
		wait for CLK_period*20;
		DOOR_OPEN <= '0';	--ZAMYKAMY drzwi
		
		wait for CLK_period *300; --przerwa
		wait for CLK_period *20; --przerwa
		
		--TEST 2. TURBO Z AWARIA--
		TRYB_PRACY <= "10"; --TURBO
		START <= '1';
		wait for CLK_period*2;
		START <= '0';
		
		wait for CLK_period*45; --Czekamy nabierze wody i zacznie mycie
		
		--KROTKA AWARIA ZASILANIA
		AWARIA_ZASILANIA <= '1';	--Odetniecie pradu
		wait for clk_period*20;
		AWARIA_ZASILANIA <= '0'; 	--Przywrocenie pradu
		
		wait for CLK_period*30; -- Czekmay chwile, by zmywarka wrocila do pracy (oczekujmey POMPA_MYJACA = '1')
		
		--SYMULACJA DLUGIEJ AWARI - KRYTYCZNEJ
		AWARIA_ZASILANIA <= '1';
		wait for CLK_period *60; 		-- WYLACZAMY PRAD NA 60CYKLI poniewaz limi to 50
		
		-- po tym czasie stan powienien zmienic sie na AWARIA_KRYTYCZNA
		-- NAWET GDY PRZYWROCIMY PRAD
		AWARIA_ZASILANIA <= '0';
		
		wait for CLK_period*30; --CZEKAMY co sie stanie
		
		RESET <= '1';
		wait for 100ns;
		RESET <= '0';
		wait for CLK_period*20;
		
		assert false severity failure;
		wait;
   end process;

END;
