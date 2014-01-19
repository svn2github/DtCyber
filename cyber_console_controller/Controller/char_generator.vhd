----------------------------------------------------------------------------
--
--  Copyright (c) 2013, Tom Hunter
--
--  Project     : CDC 6612 display controller
--  File        : char_generator.vhd
--  Description : Character generator
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License version 3 as
--  published by the Free Software Foundation.
--  
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License version 3 for more details.
--  
--  You should have received a copy of the GNU General Public License
--  version 3 along with this program in file "license-gpl-3.0.txt".
--  If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.controller.all;

entity char_generator is port
(
  clk_10mhz     : in std_logic;
  rst_n         : in std_logic;
  start_draw    : in std_logic;
  draw_char     : in std_logic_vector(5 downto 0);
  h_deflection  : out std_logic_vector(2 downto 0);
  v_deflection  : out std_logic_vector(2 downto 0);
  beam_on       : out std_logic
);
end;

architecture behavior of char_generator is

type reg_type is record
  draw_char     : std_logic_vector(5 downto 0);
  row           : integer range 0 to char_rom_rows + 1;
  h_dir         : std_logic;
  v_dir         : std_logic;
  h_inc         : integer range 0 to 3;
  v_inc         : integer range 0 to 3;
  h_deflection  : std_logic_vector(2 downto 0);
  v_deflection  : std_logic_vector(2 downto 0);
  beam_on       : std_logic;
end record;

signal data     : std_logic_vector((char_rom_bits - 1) downto 0) := (others => '0');
signal rom_char : integer range 0 to 8#77#;
signal rom_row  : integer range 0 to (char_rom_rows - 1);
signal r, rin   : reg_type;


begin

  -- Instantiate character ROM
  cr: char_rom port map (
    clk_10mhz => clk_10mhz,
    char      => rom_char,
    row       => rom_row,
    data      => data
  );

  comb_char_gen: process (rst_n, start_draw, data, draw_char, r)
  variable v      : reg_type;

  variable v1     : std_logic;
  variable v2     : std_logic;
  variable h1     : std_logic;
  variable h2     : std_logic;
  variable u      : std_logic;

  begin    
    v := r;

    -- Extract character generator codes
    v1 := data(4);
    v2 := data(3);
    h1 := data(2);
    h2 := data(1);
    u  := data(0);

    -- Handle completion
    if (v.row = char_rom_rows) then
      v.h_inc := 0;
      v.v_inc := 0;
      v.h_deflection := (others => '0');
      v.v_deflection := (others => '0');
      v.beam_on := '0';
    else
      -- Calculate new vertical deflection
      if (v1 = '1' and v2 = '1') then
        v.v_inc := 0;
        v.v_dir := not r.v_dir;
      elsif (v1 = '1') then
        v.v_inc := 1;
      elsif (v2 = '1') then
        v.v_inc := 2;
      else
        v.v_inc := 0;
      end if;

      if (v.v_dir = '0') then
        v.v_deflection := r.v_deflection - v.v_inc;
      else
        v.v_deflection := r.v_deflection + v.v_inc;
      end if;

      -- Calculate new horizontal deflection
      if (h1 = '1' and h2 = '1') then
        v.h_inc := 0;
        v.h_dir := not r.h_dir;
      elsif (h1 = '1') then
        v.h_inc := 1;
      elsif (h2 = '1') then
        v.h_inc := 2;
      else
        v.h_inc := 0;
      end if;

      if (v.h_dir = '0') then
        v.h_deflection := r.h_deflection - v.h_inc;
      else
        v.h_deflection := r.h_deflection + v.h_inc;
      end if;

      -- Control blank/unblank state
      if (u = '1') then
        v.beam_on := not r.beam_on;
      end if;  
    end if;

    -- Increment row
    if (r.row < char_rom_rows) then
      v.row := r.row + 1;
    end if;

    -- Handle startup (must be just before reset).
    if (start_draw = '1') then
      v.draw_char := draw_char;   
      v.row := 0;
      v.h_dir := '1';
      v.v_dir := '1';
      v.h_inc := 0;
      v.v_inc := 0;
      v.h_deflection := (others => '0');
      v.v_deflection := (others => '0');
      v.beam_on := '0';
    end if;

    -- Handle reset (must be last before driving register & module outputs).
    if (rst_n = '0') then
      v.draw_char := (others => '0');
      v.row := char_rom_rows;
      v.h_dir := '1';
      v.v_dir := '1';
      v.h_inc := 0;
      v.v_inc := 0;
      v.h_deflection := (others => '0');
      v.v_deflection := (others => '0');
      v.beam_on := '0';
    end if;

    -- Drive register inputs
    rin <= v;

    -- Drive module outputs (this adds one clock delay)
    beam_on       <= r.beam_on;
    rom_char      <= to_integer(unsigned(r.draw_char));
    rom_row       <= r.row;

    -- Drive module outputs (this is immediate - needed to meet DAC timing)
    -- Clock the deflection data into the DACs allowing for setup times using
    -- a 180 phase shifted 10 MHz clock. Note that the DAC output will be
    -- updated at the following falling edge of the phase shifted clock.
    h_deflection  <= v.h_deflection;
    v_deflection  <= v.v_deflection;

  end process;

  regs_char_gen: process(clk_10mhz)
  begin
    if rising_edge(clk_10mhz) then
      r <= rin;
    end if;
  end process;

end;

------------------------------- end of file --------------------------------
