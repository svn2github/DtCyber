----------------------------------------------------------------------------
--
--  Copyright (c) 2013, Tom Hunter
--
--  Project     : CDC 6612 display controller
--  File        : controller_pkg.vhd
--  Description : Defines display controller related constants, records
--                and components.
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

package controller is

  constant char_rom_bits      : integer := 5;
  constant char_rom_chars     : integer := 8#60#;
  constant char_rom_rows      : integer := 8#27#;
  constant char_rom_words     : integer := char_rom_chars * char_rom_rows;
  constant version_number     : integer := 16#010C#;

  type controller_in is record
    gpio_dip_sw   : std_logic_vector(8 downto 1);
    key_down      : std_logic;
    key_up        : std_logic;
    key_code      : std_logic_vector(5 downto 0);

  end record;

  type controller_out is record
    gpio_led      : std_logic_vector(7 downto 0);
    size_small    : std_logic;
    size_medium   : std_logic;
    unblank_left  : std_logic;
    unblank_right : std_logic;
    pos_ver       : std_logic_vector(8 downto 0);
    pos_hor       : std_logic_vector(8 downto 0);
    h_deflection  : std_logic_vector(2 downto 0);
    v_deflection  : std_logic_vector(2 downto 0);

  end record;

  component channel_interface is port
  (
    ctrl_i	      : in controller_in;
    ctrl_o	      : out controller_out;

    clk_10mhz     : in std_logic;
    clk_pci       : in std_logic;
    rst_n         : in std_logic;

    --  Read Port
    rd_addr_i     : in std_logic_vector(10 downto 0);
    rd_be_i       : in std_logic_vector(3 downto 0);
    rd_data_o     : out std_logic_vector(31 downto 0);

    --  Write Port
    wr_addr_i     : in std_logic_vector(10 downto 0);
    wr_be_i       : in std_logic_vector(7 downto 0);
    wr_data_i     : in std_logic_vector(31 downto 0);
    wr_en_i       : in std_logic;
    wr_busy_o     : out std_logic
  );
  end component;

  component char_generator is port
  (
    clk_10mhz     : in std_logic;
    rst_n         : in std_logic;
    start_draw    : in std_logic;
    draw_char     : in std_logic_vector(5 downto 0);
    h_deflection  : out std_logic_vector(2 downto 0);
    v_deflection  : out std_logic_vector(2 downto 0);
    beam_on       : out std_logic
  );
  end component;

  component char_rom is port
  (
    clk_10mhz     : in std_logic;
    char          : in integer range 0 to (char_rom_chars - 1);
    row           : in integer range 0 to (char_rom_rows - 1);
    data          : out std_logic_vector((char_rom_bits - 1) downto 0)
  );
  end component;

end controller;

------------------------------- end of file --------------------------------
