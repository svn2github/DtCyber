-------------------------------------------------------------------------------
--
-- (c) Copyright 2009-2011 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-------------------------------------------------------------------------------
-- Project    : Virtex-6 Integrated Block for PCI Express
-- File       : PIO_TX_ENGINE.vhd
-- Version    : 1.7
----
---- Description: 64 bit Local-Link Transmit Unit.
----
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity PIO_TX_ENGINE is port (

  clk                      : in std_logic;
  rst_n                    : in std_logic;

  trn_td                   : out std_logic_vector( 63 downto 0);
  trn_trem_n               : out std_logic_vector(7 downto 0);
  trn_tsof_n               : out std_logic;
  trn_teof_n               : out std_logic;
  trn_tsrc_rdy_n           : out std_logic;
  trn_tsrc_dsc_n           : out std_logic;
  trn_tdst_rdy_n           : in std_logic;
  trn_tdst_dsc_n           : in std_logic;

  req_compl_i              : in std_logic;
  compl_done_o             : out std_logic;

  req_tc_i                 : in std_logic_vector(2 downto 0);
  req_td_i                 : in std_logic;
  req_ep_i                 : in std_logic;
  req_attr_i               : in std_logic_vector(1 downto 0);
  req_len_i                : in std_logic_vector(9 downto 0);
  req_rid_i                : in std_logic_vector(15 downto 0);
  req_tag_i                : in std_logic_vector(7 downto 0);
  req_be_i                 : in std_logic_vector(7 downto 0);
  req_addr_i               : in std_logic_vector(12 downto 0);

  rd_addr_o                : out std_logic_vector(10 downto 0);
  rd_be_o                  : out std_logic_vector( 3 downto 0);
  rd_data_i                : in std_logic_vector(31 downto 0);

  completer_id_i           : in std_logic_vector(15 downto 0);
  cfg_bus_mstr_enable_i    : in std_logic

);

end PIO_TX_ENGINE;

architecture rtl of PIO_TX_ENGINE is

constant TX_CPLD_FMT_TYPE    : std_logic_vector(6 downto 0) := "1001010";

type state_type is (TX_RST_STATE, TX_CPLD_QW1 );

signal state              : state_type;
signal byte_count     : std_logic_vector(11 downto 0);
signal lower_addr     : std_logic_vector(6 downto 0);
signal rd_be_o_int    : std_logic_vector(3 downto 0);
signal req_compl_q    : std_logic;


-- Local wires

begin

  trn_tsrc_dsc_n   <= '1';
  rd_be_o <= rd_be_o_int;

  -- Present address and byte enable to memory module

  rd_addr_o <= req_addr_i(12 downto 2);
  rd_be_o_int  <=  req_be_i(3 downto 0);

-- Calculate byte count based on byte enable

process(rd_be_o_int)
begin

  case  rd_be_o_int(3 downto 0) is

    when X"9" => byte_count <= X"004";
    when X"B" => byte_count <= X"004";
    when X"D" => byte_count <= X"004";
    when X"F" => byte_count <= X"004";
    when X"5" => byte_count <= X"003";
    when X"7" => byte_count <= X"003";
    when X"A" => byte_count <= X"003";
    when X"E" => byte_count <= X"003";
    when X"3" => byte_count <= X"002";
    when X"6" => byte_count <= X"002";
    when X"C" => byte_count <= X"002";
    when X"1" => byte_count <= X"001";
    when X"2" => byte_count <= X"001";
    when X"4" => byte_count <= X"001";
    when X"8" => byte_count <= X"001";
    when X"0" => byte_count <= X"001";
    when others => byte_count <= X"001";

  end case;

end process;

-- Calculate lower address based on  byte enable

process(rd_be_o_int, req_addr_i)
begin

   if (rd_be_o_int(0) = '1') then


      -- when "---1"
      lower_addr <= req_addr_i(6 downto 2) & "00";

   elsif (rd_be_o_int(1) = '1') then

      -- when "--10"
      lower_addr <= req_addr_i(6 downto 2) & "01";

   elsif (rd_be_o_int(2) = '1') then

      -- when "-100"
      lower_addr <= req_addr_i(6 downto 2) & "10";

   elsif (rd_be_o_int(3) = '1') then

      -- when "1000"
      lower_addr <= req_addr_i(6 downto 2) & "11";

   else

      -- when "0000"
      lower_addr <= req_addr_i(6 downto 2) & "00";

   end if;


end process;


process (rst_n, clk)
begin
  
  if (rst_n = '0') then
    
    req_compl_q <= '0';
    
  else

    if (clk'event and clk = '1') then

      req_compl_q <= req_compl_i;
      
    end if;

  end if;

end process;


--  State Machine to generate Completion with 1 DW Payload or Completion without Data

process (rst_n, clk)
begin

  if (rst_n = '0' ) then

    trn_tsof_n        <= '1';
    trn_teof_n        <= '1';
    trn_tsrc_rdy_n    <= '1';
    trn_td            <= (others => '0'); -- 64-bits
    trn_trem_n    <= (others => '0'); -- 8-bits
    compl_done_o      <= '0';
    state             <= TX_RST_STATE;

  else

    if (clk'event and clk = '1') then

      compl_done_o      <= '0';

      case ( state ) is

        when TX_RST_STATE =>

          if ((trn_tdst_rdy_n = '0') and (req_compl_q = '1') and (trn_tdst_dsc_n = '1')) then

            trn_tsof_n       <= '0';
            trn_teof_n       <= '1';
            trn_tsrc_rdy_n   <= '0';
            trn_td           <= '0' &
                                TX_CPLD_FMT_TYPE &
                                '0' &
                                req_tc_i &
                                "0000" &
                                req_td_i &
                                req_ep_i &
                                req_attr_i &
                                "00" &
                                req_len_i &
                                completer_id_i &
                                "000" &
                                '0' &
                                byte_count;
            trn_trem_n       <= (others => '0'); -- 8-bit
            state            <= TX_CPLD_QW1;
       
         else

            trn_tsof_n       <= '1';
            trn_teof_n       <= '1';
            trn_tsrc_rdy_n   <= '1';
            trn_td           <= (others => '0'); -- 64-bit
            trn_trem_n       <= (others => '0'); -- 8-bit
            compl_done_o     <= '0';
            state            <= TX_RST_STATE;

          end if;


        when TX_CPLD_QW1 =>

          if ((trn_tdst_rdy_n = '0') and (trn_tdst_dsc_n = '1')) then

            trn_tsof_n       <= '1';
            trn_teof_n       <= '0';
            trn_tsrc_rdy_n   <= '0';
            trn_td           <= req_rid_i &
                                req_tag_i &
                                '0' &
                                lower_addr &
                                rd_data_i;
            trn_trem_n       <= "00000000";
            compl_done_o     <= '1';
            state            <= TX_RST_STATE;

          elsif (trn_tdst_dsc_n = '0') then

            state            <= TX_RST_STATE;


          else

            state           <= TX_CPLD_QW1;

          end if;

        when others => NULL;

      end case;

    end if;

  end if;

end process;

end; -- PIO_TX_ENGINE

