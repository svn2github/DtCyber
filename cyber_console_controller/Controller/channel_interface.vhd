----------------------------------------------------------------------------
--
--  Copyright (c) 2013, Tom Hunter
--
--  Project     : CDC 6612 display controller
--  File        : channel_interface.vhd
--  Description : Channel interface and 6612 controller logic.
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

entity channel_interface is port
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
end;

architecture behavior of channel_interface is

subtype cmd_type is integer range 0 to 7;

constant PciCmdNop          : cmd_type := 0;
constant PciCmdFunction     : cmd_type := 1;
constant PciCmdFull         : cmd_type := 2;
constant PciCmdEmpty        : cmd_type := 3;
constant PciCmdActive       : cmd_type := 4;
constant PciCmdInactive     : cmd_type := 5;
constant PciCmdClear        : cmd_type := 6;
constant PciCmdMasterClear  : cmd_type := 7;
                            
constant PciStaFull         : cmd_type := 1;
constant PciStaActive       : cmd_type := 2;
constant PciStaBusy         : cmd_type := 4;

type pci_reg_type is record
  wr_data       : std_logic_vector(15 downto 0);
  status        : std_logic_vector(15 downto 0);
  pci_cmd       : cmd_type;
  cha_active    : std_logic;
  cha_full      : std_logic;

  -- Cross clock domain output toggle flags
  cmd_busy      : std_logic;

  -- Cross clock domain input toggle flags
  sync_finished : std_logic;
  cmd_finished  : std_logic;
  old_finished  : std_logic;
  sync_status   : std_logic;
  update_status : std_logic;
  old_status    : std_logic;
end record;

type ctrl_reg_type is record
  -- Controller status
  pci_cmd       : cmd_type;
  selected      : std_logic;
  mode_char     : std_logic;
  mode_dot      : std_logic;
  mode_keyb     : std_logic;
  screen_left   : std_logic;
  screen_right  : std_logic;
  start_char    : std_logic;
  start_dot     : std_logic;
  cycle_count   : integer range 0 to 127;
  cha_active    : std_logic;
  cha_full      : std_logic;
  key_down_count: integer range 0 to 65535;
  key_up_count  : integer range 0 to 65535;
  key_latch     : std_logic;
  key_processed : std_logic;
  key_code      : std_logic_vector(5 downto 0);
  spacing       : integer range 0 to 63;

  -- Outputs
  size_small    : std_logic;
  size_medium   : std_logic;
  unblank_left  : std_logic;
  unblank_right : std_logic;
  pos_ver       : std_logic_vector(8 downto 0);
  pos_hor       : std_logic_vector(8 downto 0);
  draw_char     : std_logic_vector(5 downto 0);
  start_draw    : std_logic;

  -- Cross clock domain output toggle flags
  cmd_finished  : std_logic;
  update_status : std_logic;

  -- Cross clock domain input toggle flags
  sync_busy    : std_logic;
  cmd_busy     : std_logic;
  old_busy     : std_logic;
end record;

signal start_draw       : std_logic;
signal draw_char        : std_logic_vector(5 downto 0);
signal beam_on          : std_logic;
signal pci_r,  pci_rin  : pci_reg_type;
signal ctrl_r, ctrl_rin : ctrl_reg_type;

attribute keep : string;

------- DEBUG +
-- signal keep_wr_addr_i   : std_logic_vector(10 downto 0);
-- signal keep_wr_be_i     : std_logic_vector(7 downto 0);
-- signal keep_wr_data_i   : std_logic_vector(31 downto 0);
-- signal keep_wr_en_i     : std_logic;
-- 
-- attribute keep of keep_wr_addr_i : signal is "true";
-- attribute keep of keep_wr_be_i   : signal is "true";
-- attribute keep of keep_wr_data_i : signal is "true";
-- attribute keep of keep_wr_en_i   : signal is "true";
------- DEBUG -

begin

------- DEBUG +
-- keep_wr_addr_i  <= wr_addr_i;
-- keep_wr_be_i    <= wr_be_i;  
-- keep_wr_data_i  <= wr_data_i;
-- keep_wr_en_i    <= wr_en_i;  
------- DEBUG -

  -- Instantiate character generator
  cg: char_generator port map (
    clk_10mhz       => clk_10mhz,          
    rst_n           => rst_n,
    start_draw      => start_draw,   
    draw_char       => draw_char,
    h_deflection    => ctrl_o.h_deflection, 
    v_deflection    => ctrl_o.v_deflection, 
    beam_on         => beam_on      
  );

  --
  -- Combinational process for PCI-Express clock domain
  --
  comb_pci: process (rst_n, rd_addr_i, rd_be_i, wr_en_i, wr_addr_i, wr_be_i, wr_data_i, pci_r, ctrl_r)
  variable v : pci_reg_type;
  begin    
    v := pci_r;

    -- Synch cmd_finished signal
    v.sync_finished := ctrl_r.cmd_finished;
    v.cmd_finished := pci_r.sync_finished;

    -- Synch update_status signal
    v.sync_status := ctrl_r.update_status;
    v.update_status := pci_r.sync_status;

    -- Handle channel status update
    if ((v.update_status xor v.old_status) = '1') then
      v.old_status := v.update_status;
      v.cha_active := ctrl_r.cha_active;
      v.cha_full   := ctrl_r.cha_full;  
    end if;

    -- Handle PCI write
    if (wr_en_i = '1' and to_integer(unsigned(wr_addr_i(6 downto 0))) = 0 and wr_be_i(3 downto 0) = "0011") then
      v.wr_data(15 downto 8) := wr_data_i(23 downto 16);
      v.wr_data( 7 downto 0) := wr_data_i(31 downto 24);

      -- Decode emulator command
      v.pci_cmd := to_integer(unsigned(v.wr_data(15 downto 13)));

      -- Immediately set channel status
      case (v.pci_cmd) is 
        when PciCmdNop =>
          -- do nothing

        when PciCmdFunction =>
          v.cha_active := '1';
          v.cha_full := '1';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdFull =>      
          v.cha_full := '1';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdEmpty =>      
          v.cha_full := '0';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdActive =>     
          v.cha_active := '1';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdInactive =>   
          v.cha_active := '0';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdClear =>      
          v.cha_active := '0';
          v.cha_full := '0';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;

        when PciCmdMasterClear =>
          v.cha_active := '0';
          v.cha_full := '0';
          v.cmd_busy := not v.cmd_busy;
          v.old_finished := not v.cmd_finished;
      end case;
    end if;

    -- Handle PCI reads (status, version number and others)
    if (rd_be_i(3 downto 0) = "0011") then
      case (to_integer(unsigned(rd_addr_i(6 downto 0)))) is
        when 0 =>
          -- Output channel status
          v.status(5  downto 0) := ctrl_r.key_code;
          v.status(12 downto 6) := (others => '0');
          v.status(13)          := v.cha_full;
          v.status(14)          := v.cha_active;
          v.status(15)          := v.cmd_finished xor v.old_finished;
        when 1 =>
          v.status := std_logic_vector(to_unsigned(version_number, v.status'length));
        when others =>
          v.status := X"0000";
      end case;
    else
      v.status := (others => '0');
    end if;

    -- Handle reset (must be last before driving register & module outputs).
    if (rst_n = '0') then
      v.wr_data       := (others => '0');
      v.status        := (others => '0');
      v.pci_cmd       := PciCmdNop;
      v.cha_active    := '0';
      v.cha_full      := '0';
      v.cmd_busy      := '0';
      v.sync_finished := '0';
      v.cmd_finished  := '0';
      v.old_finished  := '0';
      v.sync_status   := '0';
      v.update_status := '0';
      v.old_status    := '0';
    end if;

    -- Drive register inputs
    pci_rin <= v;

    -- Drive module outputs (this adds one clock delay)
    ctrl_o.gpio_led(7) <= pci_r.cmd_finished xor v.old_finished;
    ctrl_o.gpio_led(6) <= pci_r.cha_active;
    ctrl_o.gpio_led(5) <= pci_r.cha_full;
    ctrl_o.gpio_led(2 downto 0) <= std_logic_vector(to_unsigned(pci_r.pci_cmd, 3));

    -- Drive module outputs (this has effect immediately)
    rd_data_o(31 downto 24) <= v.status(7  downto 0);
    rd_data_o(23 downto 16) <= v.status(15 downto 8);
    rd_data_o(15 downto  0) <= (others => '0');
    wr_busy_o <= wr_en_i;
  end process;

  --
  -- Update registers
  --
  regs_pci : process(clk_pci)
  begin
    if rising_edge(clk_pci) then
      pci_r <= pci_rin;
    end if;
  end process;

  --
  -- Combinational process for 10 MHz CYBER clock domain
  --
  comb_ctrl: process (rst_n, ctrl_i, beam_on, ctrl_r, pci_r)
  variable v : ctrl_reg_type;
  begin    
    v := ctrl_r;

    -- Synch cmd_busy signal
    v.sync_busy := pci_r.cmd_busy;
    v.cmd_busy := ctrl_r.sync_busy;

    -- Handle new command from emulator
    if ((v.cmd_busy xor v.old_busy) = '1') then
      -- Indicate acceptance and prevent being re-started immediately again
      v.cmd_finished := not v.cmd_finished;
      v.old_busy := v.cmd_busy;

      -- Decode emulator command
      v.pci_cmd := to_integer(unsigned(pci_r.wr_data(15 downto 13)));

      case (v.pci_cmd) is 
        when PciCmdNop =>
          -- do nothing

        when PciCmdFunction =>
          -- Are we selected?
          if (pci_r.wr_data(11 downto 9) = "111") then
            v.selected := '1';

            -- Decode character size
            case (pci_r.wr_data(2 downto 0)) is
              when "000" =>
                v.size_small  := '1';
                v.size_medium := '0';
                v.spacing     := 8;

              when "001" =>
                v.size_small  := '0';
                v.size_medium := '1';
                v.spacing     := 16;

              when "010" =>
                v.size_small  := '1';
                v.size_medium := '1';
                v.spacing     := 32;

              when others =>
                -- leave character size alone
            end case;

            -- Decode operating mode
            case (pci_r.wr_data(5 downto 3)) is
              when "000" =>
                v.mode_char := '1';
                v.mode_dot  := '0';
                v.mode_keyb := '0';

              when "001" =>
                v.mode_char := '0';
                v.mode_dot  := '1';
                v.mode_keyb := '0';

              when "010" =>
                v.mode_char := '0';
                v.mode_dot  := '0';
                v.mode_keyb := '1';

              when others =>
                -- leave mode alone
            end case;

            -- Decode screen selector
            case (pci_r.wr_data(8 downto 6)) is
              when "000" =>
                v.screen_left  := '1';
                v.screen_right := '0';

              when "001" =>
                v.screen_left  := '0';
                v.screen_right := '1';

              when "100" =>
                v.screen_left  := '1';
                v.screen_right := '1';

              when others =>
                -- leave screens alone
            end case;

            -- Function has been fully processed
            v.cha_active := '0';
            v.cha_full   := '0';
            v.update_status := not ctrl_r.update_status;
          end if;
      
        when PciCmdFull =>
          if (v.selected = '1' and v.cha_active = '1') then
            v.cha_full := '0';
            if (pci_r.wr_data(11 downto 9) = "111") then
              -- Vertical position - do we have to allow for beam settling time if not in dot mode ????
              v.pos_ver := pci_r.wr_data(8 downto 0);
              if (v.mode_dot = '1') then
                -- In dot mode display at this position
                v.cha_full := '1';
                v.start_dot := '1';
                v.cycle_count := 0;
              end if;
            elsif (pci_r.wr_data(11 downto 9) = "110") then
              -- Horizontal position - do we have to allow for beam settling time ????
              v.pos_hor := pci_r.wr_data(8 downto 0);
            else
              if (v.mode_char = '1') then
                -- Display both characters
                v.cha_full := '1';
                v.start_char := '1';
                v.cycle_count := 0;
              end if;
            end if;
          end if;
          v.update_status := not ctrl_r.update_status;

        when PciCmdEmpty =>      
          v.cha_full := '0';
          if (v.key_processed = '1') then
            v.key_processed := '0';
            v.key_code := (others => '0');
          end if;

        when PciCmdActive =>     
          v.cha_active := '1';
          if (v.mode_keyb = '1') then
            v.cha_full := '1';
            if (v.key_latch = '1') then
              v.key_processed := '1';
            end if;
          end if;
          v.update_status := not ctrl_r.update_status;

        when PciCmdInactive =>   
          v.cha_active := '0';
          v.mode_keyb := '0';
          v.update_status := not ctrl_r.update_status;

        when PciCmdClear =>      
          v.cha_full := '0';
          v.update_status := not ctrl_r.update_status;

        when PciCmdMasterClear =>
          v.cha_active := '0';
          v.cha_full   := '0';
          v.update_status := not ctrl_r.update_status;
      end case;
    end if;

    -- Handle key down
    if (ctrl_i.key_down = '0') then
      if (ctrl_r.key_latch = '0') then
        -- Debounce key down signal
        if (ctrl_r.key_down_count = 60000) then
          -- Latch key code
          v.key_latch := '1';
          v.key_code := ctrl_i.key_code;
        else
          v.key_down_count := ctrl_r.key_down_count + 1;
        end if;
      end if;
    else
      v.key_down_count := 0;
    end if;

    -- Handle key up
    if (ctrl_i.key_up = '0') then
      -- Debounce key up signal
      if (ctrl_r.key_up_count = 60000) then
        -- Rearm keyboard logic
        v.key_latch := '0';
      else
        v.key_up_count := ctrl_r.key_up_count + 1;
      end if;
    else
      v.key_up_count := 0;
    end if;

    -- Process dot sequencing
    if (ctrl_r.start_dot = '1') then
      if (v.cycle_count = 44) then
        -- Turn on dot for 400 ns
        v.unblank_left  := v.screen_left;
        v.unblank_right := v.screen_right;
      end if;
      if (v.cycle_count = 48) then
        v.unblank_left  := '0';
        v.unblank_right := '0';
      end if;
      if (v.cycle_count = 57) then
        v.start_dot := '0';
        v.cha_full  := '0';
        v.update_status := not ctrl_r.update_status;
      end if;
      v.cycle_count := ctrl_r.cycle_count + 1;
    end if;

    -- Process char sequencing
    -- Take into account the 200 ns startup delay of the character generator
    if (ctrl_r.start_char = '1') then
      v.unblank_left  := v.screen_left  and beam_on;
      v.unblank_right := v.screen_right and beam_on;

      if (v.cycle_count = 9) then
        v.start_draw := '1';
        v.draw_char  := pci_r.wr_data(11 downto 6);
      end if;

      if (v.cycle_count = 10) then
        v.start_draw := '0';
      end if;

      if (v.cycle_count = 35) then
        v.pos_hor := ctrl_r.pos_hor + v.spacing;
      end if;

      if (v.cycle_count = 45) then
        v.start_draw := '1';
        v.draw_char  := pci_r.wr_data(5 downto 0);
      end if;

      if (v.cycle_count = 46) then
        v.start_draw := '0';
      end if;

      if (v.cycle_count = 71) then
        v.pos_hor := ctrl_r.pos_hor + v.spacing;
        v.start_char := '0';
        v.cha_full   := '0';
        v.update_status := not ctrl_r.update_status;
      end if;

      v.cycle_count := ctrl_r.cycle_count + 1;
    end if;

    -- Handle reset (must be last before driving register & module outputs).
    if (rst_n = '0') then
      v.pci_cmd       := PciCmdNop;
      v.selected      := '0';
      v.mode_char     := '0';
      v.mode_dot      := '0';
      v.mode_keyb     := '0';
      v.screen_left   := '0';
      v.screen_right  := '0';
      v.start_char    := '0';
      v.start_dot     := '0';
      v.cycle_count   := 0;
      v.cha_active    := '0';
      v.cha_full      := '0';
      v.key_down_count:= 0;
      v.key_up_count  := 0;
      v.key_latch     := '0';
      v.key_processed := '0';
      v.key_code      := (others => '0');
      v.size_small    := '0';
      v.size_medium   := '0';
      v.unblank_left  := '0';
      v.unblank_right := '0';
      v.pos_ver       := (others => '0');
      v.pos_hor       := (others => '0');
      v.draw_char     := (others => '0');
      v.start_draw    := '0';
      v.cmd_finished  := '0';
      v.update_status := '0';
      v.sync_busy     := '0';
      v.cmd_busy      := '0';
      v.old_busy      := '0';
    end if;

    -- Drive register inputs
    ctrl_rin <= v;

    -- Drive module outputs (this adds one clock delay)
    ctrl_o.gpio_led(4) <= ctrl_r.start_char;
    ctrl_o.gpio_led(3) <= ctrl_r.start_dot;

    -- From Display_Controller_from_DA4000_Cyber_Hardware_For_Analysts_Section_1.pdf page 1-11:
    -- The following outputs have to be inverted (unblank_left, unblank_right, pos_ver, pos_hor)
    --
    -- Drive module outputs (this has effect immediately)
    ctrl_o.pos_ver       <= not v.pos_ver;
    ctrl_o.pos_hor       <= not v.pos_hor;
    ctrl_o.size_small    <= v.size_small;  
    ctrl_o.size_medium   <= v.size_medium;
    ctrl_o.unblank_left  <= not v.unblank_left;
    ctrl_o.unblank_right <= not v.unblank_right;
    start_draw           <= v.start_draw;
    draw_char            <= v.draw_char;
  end process;

  --
  -- Update registers
  --
  regs_10mhz : process(clk_10MHz)
  begin
    if rising_edge(clk_10MHz) then
      ctrl_r <= ctrl_rin;
    end if;
  end process;

end;

------------------------------- end of file --------------------------------

