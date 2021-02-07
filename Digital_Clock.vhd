library ieee;
use IEEE.STD_LOGIC_UNSIGNED.ALL;  
use ieee.std_logic_1164.all;

entity digital_clock is
port(
  clk_signal : in std_logic; --clk_signal of frequency 100Mhz
  reset_button : in std_logic; 
  mode_button : in std_logic; 
  increment_button : in std_logic; 
  set_time_button : in std_logic;   
  cathode_out : out BIT_vector(6 downto 0);
  Anode_activate : out BIT_vector(3 downto 0); 
  LED_Blink : out BIT); 
end entity;

architecture behaviour of digital_clock is
signal ss : integer range 0 to 59;
signal mm : integer range 0 to 59;
signal count : integer := 0;
signal one_second_completed : std_logic := '1';
signal hour : integer range 0 to 23;
signal temp_blink : BIT :='1';
signal ds1 : BIT :='1'; --hh:mm display else mm:ss display
-- if 2 then fast increment
--if 0 no increment
-- if 1 slow increment
signal increase_hour: integer := 0; 
signal increase_minute: integer := 0; 
signal increase_second: integer := 0;
signal reset_pressed : BIT :='0';
signal set_pressed : integer := 0; 
signal LED_BCD: integer := 0;
signal 1ms_completed : std_logic :='1';
signal 4ms_completed : integer := 0;
signal time_increment_button_pressed : integer := 0;
signal increment_pressed : BIT := '0';
begin
second_processing : process(clk_signal)
  begin
    if (rising_edge(clk_signal)) then
      if(falling_edge(reset_button)) then
        count <= 0;
        hour <= 0;
        mm <= 0;
        ss <= 0;
      end if;
      count <= count + 1;
      if (count = 100000000) then
        one_second_completed <= not one_second_completed;
      end if;
      if( count = 50000000 or count = 100000000) then 
        temp_blink <= not temp_blink;
        temp_blink <= (temp_blink and (not(Anode_activate(2))));
        LED_Blink <= temp_blink;
      end if;
      if((count rem 100000) = 0) then
        1ms_completed = not 1ms_completed;
      end if;
      if((count rem 400000) = 0) then
        4ms_completed <= (4ms_completed + 1) rem 4;
      end if;
    end if;
    if(count=100000000) then
      count<=0;
    end if;
  end process;
-- refresh rate of 12ms(each segment displayed for 3ms)
Output_CLock : process(1ms_completed)
  begin 
    if(4ms_completed = 0) then 
      Anode_activate <= '0111';
      if(reset_pressed) then LED_BCD <= 0;
      else
        if(ds1) then
          LED_BCD <= hour/10;
        else 
          LED_BCD <= mm/10;
        end if;
      end if;
    end if;
    if(4ms_completed = 1) then 
      if(reset_pressed) then LED_BCD <= 0;
      else
        Anode_activate <= '1011';
        if(ds1) then
          LED_BCD <= hour rem 10;
        else 
          LED_BCD <= mm rem 10;
        end if;
      end if;
    end if;
    if(4ms_completed = 2) then 
      if(reset_pressed) then LED_BCD <= 0;
      else
        Anode_activate <= '1101';
        if(ds1) then
          LED_BCD <= mm/10;
        else
          LED_BCD <= ss/10;
        end if;
      end if;
    end if;
    if(4ms_completed = 3) then 
      if(reset_pressed) then LED_BCD <= 0;
      else
        Anode_activate <= '1110';
        if(ds1) then
          LED_BCD <= mm rem 10;
        else
          LED_BCD <= ss rem 10;
        end if;
        reset_pressed = not reset_pressed;
      end if;
    end if;
  end process;
-- state transitions for buttons
Buttons : process(1ms_completed)
  begin
    if(falling_edge(mode_button) and set_pressed = 0) then ds1 <= not ds1;
    end if;
    if(falling_edge(reset_button)) then
      reset_pressed <= not reset_pressed;
    end if;
    if(falling_edge(set_time_button)) then 
      set_pressed <= set_pressed + 1;
      set_pressed <= set_pressed rem 3;
    end if;
    if(set_pressed = 1 or set_pressed = 2) then
      if(increment_button) then
        increment_pressed <= '1';
      end if;
    end if;
  end process;
-- cheking how much to increase
-- if increment button is pressed for more than 2 sec then fast increment will begin
-- just a single press and release on increment for less than 2 sec is considered as an increment by 1
-- hh,mm,ss can be increased independently
Fast_Increment : process(1ms_completed)
  begin
    if(increment_pressed = '1') then
      if(time_increment_button_pressed = 2) then
        if(set_pressed = 1) then
          if(ds1) then
            increase_hour <= 2;
          else
            increase_minute <= 2;
        elsif(set_pressed = 2) then
          if(ds1) then
            increase_minute <= 2;
          else
            increase_second <= 2;
          end if;
          end if;
        end if;
      else
        if(falling_edge(increment_button)) then
          if(set_pressed = 1) then
            if(ds1) then
              increase_hour <= 1;
            else
              increase_minute <=1;
            end if;
          elsif(set_pressed = 2) then
            if(ds1) then
              increase_minute <= 1;
            else
              increase_second <= 1;
            end if;
          end if;
        end if;
      end if;
    end if;
    if(falling_edge(increment_button)) then
      time_increment_button_pressed <= 0;
      increment_pressed <= '0';
    end if;
  end process;
--
increment_time : process(one_second_completed)
  begin
    if(increment_button) then
      if(time_increment_button_pressed = 0 or time_increment_button_pressed = 1)
        time_increment_button_pressed <= time_increment_button_pressed+1;
      end if;
    end if;
    case increase_hour is
    when 1 => hour <= (hour + 1) rem 24;
    when 2 => hour <= (hour + 4)  rem 24;
    end case;
    case increase_minute is
    when 1 => mm <= (mm + 1) rem 60;
    when 2 => mm <= (mm + 4) rem 60;
    end case;
    case increase_second is
    when 1 => ss <= (ss + 1) rem 60;
    when 2 => ss <= (ss + 4) rem 60;
    end case;
    if(increment_button = '0') then
      increase_hour <= 0;
      increase_minute <= 0;
      increase_second <= 0;
    end if;
  end process;
--
BCD_converter : process(LED_BCD)
begin
    case LED_BCD is
    when 0 => cathode_out <= "0000001";      
    when 1 => cathode_out <= "1001111";  
    when 2 => cathode_out <= "0010010";  
    when 3 => cathode_out <= "0000110";  
    when 4 => cathode_out <= "1001100";  
    when 5 => cathode_out <= "0100100";  
    when 6 => cathode_out <= "0100000";  
    when 7 => cathode_out <= "0001111";  
    when 8 => cathode_out <= "0000000";      
    when 9 => cathode_out <= "0000100";  
    end case;
end process;


-- adding regular second to digital clock
digital : process (one_second_completed)
 begin
  if (rising_edge(one_second_completed)) then
   if (ss = 59) then
    ss <= 0;
    if (mm = 59) then
     mm <= 0;
     if (hour = 23) then
      hour <= 0;
     else
      hour <= hour + 1;
     end if;
    else
     mm <= mm + 1;
    end if;
   else
    ss <= ss + 1;
   end if;
  end if;
 end process; 
end behaviour;
