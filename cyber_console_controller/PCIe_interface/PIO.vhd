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
-- Project    : CDC 6612 display controller
-- File       : PIO.vhd
-- Version    : 1.7
----
---- Description: Programmed I/O module. Design implements 128 Bytes of memory space.
----              
----              Module is designed to operate with 32 bit and 64 bit interfaces.
----
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.controller.all;

entity PIO is

port (
  ctrl_i				 : in controller_in;
  ctrl_o				 : out controller_out;

  clk_10mhz              : in std_logic;

  trn_clk                : in std_logic;         
  trn_reset_n            : in std_logic;
  trn_lnk_up_n           : in std_logic;

  trn_td                 : out std_logic_vector(63 downto 0);
  trn_trem_n             : out std_logic_vector(7 downto 0);

  trn_tsof_n             : out std_logic;
  trn_teof_n             : out std_logic;
  trn_tsrc_rdy_n         : out std_logic;
  trn_tsrc_dsc_n         : out std_logic;
  trn_tdst_rdy_n         : in std_logic;
  trn_tdst_dsc_n         : in std_logic;

  trn_rd                 : in std_logic_vector(63 downto 0);
  trn_rrem_n             : in std_logic_vector(7 downto 0);
  trn_rsof_n             : in std_logic;
  trn_reof_n             : in std_logic;
  trn_rsrc_rdy_n         : in std_logic;
  trn_rsrc_dsc_n         : in std_logic;
  trn_rbar_hit_n         : in std_logic_vector(6 downto 0);
  trn_rdst_rdy_n         : out std_logic;
  cfg_to_turnoff_n       : in std_logic;
  cfg_turnoff_ok_n       : out std_logic;

  cfg_completer_id       : in std_logic_vector(15 downto 0);
  cfg_bus_mstr_enable    : in std_logic

);    

end PIO;

architecture rtl of PIO is	 

-- Local wires

signal req_compl      : std_logic;
signal compl_done     : std_logic;
signal pio_reset_n    : std_logic;

component PIO_EP

port (
  ctrl_i				 : in controller_in;
  ctrl_o				 : out controller_out;

  clk_10mhz              : in std_logic;
  clk                    : in std_logic;
  rst_n                  : in std_logic;

  -- LocalLink Tx

  trn_td                 : out std_logic_vector(63 downto 0);
  trn_trem_n             : out std_logic_vector(7 downto 0);

  trn_tsof_n             : out std_logic;
  trn_teof_n             : out std_logic;
  trn_tsrc_dsc_n         : out std_logic;
  trn_tsrc_rdy_n         : out std_logic;
  trn_tdst_dsc_n         : in std_logic;
  trn_tdst_rdy_n         : in std_logic;

  -- LocalLink Rx

  trn_rd                 : in std_logic_vector(63 downto 0);
  trn_rrem_n             : in std_logic_vector(7 downto 0);

  trn_rsof_n             : in std_logic;
  trn_reof_n             : in std_logic;
  trn_rsrc_rdy_n         : in std_logic;
  trn_rsrc_dsc_n         : in std_logic;
  trn_rbar_hit_n         : in std_logic_vector(6 downto 0);
  trn_rdst_rdy_n         : out std_logic;

  req_compl_o            : out std_logic;
  compl_done_o           : out std_logic;

  cfg_completer_id       : in std_logic_vector(15 downto 0);
  cfg_bus_mstr_enable    : in std_logic
);
end component;


component PIO_TO_CTRL
port (

  clk : in std_logic;
  rst_n : in std_logic;

  req_compl_i : in std_logic;
  compl_done_i : in std_logic;

  cfg_to_turnoff_n : in std_logic;
  cfg_turnoff_ok_n : out std_logic
);
end component;

begin

pio_reset_n  <= not trn_lnk_up_n;

-- PIO instance

PIO_EP_ins : PIO_EP

port map (
  ctrl_i => ctrl_i,                          -- I
  ctrl_o => ctrl_o,                          -- O

  clk_10mhz => clk_10mhz,                    -- I
  clk => trn_clk,                            -- I
  rst_n => pio_reset_n,                      -- I

  trn_td => trn_td,                          -- O [127/63:0]
  trn_trem_n => trn_trem_n,                  -- O [1/0:0]
  trn_tsof_n => trn_tsof_n,                  -- O
  trn_teof_n => trn_teof_n,                  -- O
  trn_tsrc_rdy_n => trn_tsrc_rdy_n,          -- O
  trn_tsrc_dsc_n => trn_tsrc_dsc_n,          -- O
  trn_tdst_rdy_n => trn_tdst_rdy_n,          -- I
  trn_tdst_dsc_n => trn_tdst_dsc_n,          -- I

  trn_rd => trn_rd,                          -- I [127/63:0]
  trn_rrem_n => trn_rrem_n,                  -- I [1/0:0]
  trn_rsof_n => trn_rsof_n,                  -- I
  trn_reof_n => trn_reof_n,                  -- I
  trn_rsrc_rdy_n => trn_rsrc_rdy_n,          -- I
  trn_rsrc_dsc_n => trn_rsrc_dsc_n,          -- I
  trn_rbar_hit_n => trn_rbar_hit_n,          -- I
  trn_rdst_rdy_n => trn_rdst_rdy_n,          -- O

  req_compl_o => req_compl,                  -- O
  compl_done_o => compl_done,                -- O

  cfg_completer_id => cfg_completer_id,      -- I [15:0]
  cfg_bus_mstr_enable => cfg_bus_mstr_enable -- I

);


    --
    -- Turn-Off controller
    --

PIO_TO : PIO_TO_CTRL port map   (

   clk => trn_clk,                             -- I
   rst_n => trn_reset_n,                       -- I

   req_compl_i => req_compl,                   -- I
   compl_done_i => compl_done,                 -- I

   cfg_to_turnoff_n => cfg_to_turnoff_n,       -- I
   cfg_turnoff_ok_n => cfg_turnoff_ok_n        -- O

);

end;  -- PIO
