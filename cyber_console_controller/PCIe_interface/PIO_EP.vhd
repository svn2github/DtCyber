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
-- File       : PIO_EP.vhd
-- Version    : 1.7
----
---- Description: Endpoint Programmed I/O module. 
----
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.controller.all;

entity PIO_EP is

port (
  ctrl_i                 : in controller_in;
  ctrl_o                 : out controller_out;

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
end PIO_EP;
    
architecture rtl of PIO_EP is
 
-- Local signals
    
  signal rd_addr       : std_logic_vector(10 downto 0); 
  signal rd_be         : std_logic_vector(3 downto 0); 
  signal rd_data       : std_logic_vector(31 downto 0); 

  signal wr_addr       : std_logic_vector(10 downto 0); 
  signal wr_be         : std_logic_vector(7 downto 0); 
  signal wr_data       : std_logic_vector(31 downto 0); 
  signal wr_en         : std_logic;
  signal wr_busy       : std_logic;

  signal req_compl     : std_logic;
  signal compl_done    : std_logic;

  signal req_tc        : std_logic_vector(2 downto 0);
  signal req_td        : std_logic; 
  signal req_ep        : std_logic; 
  signal req_attr      : std_logic_vector(1 downto 0);
  signal req_len       : std_logic_vector(9 downto 0);
  signal req_rid       : std_logic_vector(15 downto 0);
  signal req_tag       : std_logic_vector(7 downto 0);
  signal req_be        : std_logic_vector(7 downto 0);
  signal req_addr      : std_logic_vector(12 downto 0);

component PIO_RX_ENGINE is
port (

  clk               : in std_logic;
  rst_n             : in std_logic;

  trn_rd            : in std_logic_vector(63 downto 0);
  trn_rrem_n        : in std_logic_vector(7 downto 0);
  trn_rsof_n        : in std_logic;
  trn_reof_n        : in std_logic;
  trn_rsrc_rdy_n    : in std_logic;
  trn_rsrc_dsc_n    : in std_logic;
  trn_rbar_hit_n    : in std_logic_vector(6 downto 0);
  trn_rdst_rdy_n    : out std_logic;

  req_compl_o       : out std_logic;
  compl_done_i      : in std_logic;

  req_tc_o          : out std_logic_vector(2 downto 0); -- Memory Read TC
  req_td_o          : out std_logic; -- Memory Read TD
  req_ep_o          : out std_logic; -- Memory Read EP
  req_attr_o        : out std_logic_vector(1 downto 0); -- Memory Read Attribute
  req_len_o         : out std_logic_vector(9 downto 0); -- Memory Read Length (1DW)
  req_rid_o         : out std_logic_vector(15 downto 0); -- Memory Read Requestor ID
  req_tag_o         : out std_logic_vector(7 downto 0); -- Memory Read Tag
  req_be_o          : out std_logic_vector(7 downto 0); -- Memory Read Byte Enables
  req_addr_o        : out std_logic_vector(12 downto 0); -- Memory Read Address

  wr_addr_o         : out std_logic_vector(10 downto 0); -- Memory Write Address
  wr_be_o           : out std_logic_vector(7 downto 0); -- Memory Write Byte Enable
  wr_data_o         : out std_logic_vector(31 downto 0); -- Memory Write Data
  wr_en_o           : out std_logic; -- Memory Write Enable
  wr_busy_i         : in std_logic -- Memory Write Busy

);
end component;

component PIO_TX_ENGINE is

port   (

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
end component;

begin

-- ENDPOINT 6612 display controller

EP_CONTROLLER : channel_interface port map (
  ctrl_i => ctrl_i,                     -- I
  ctrl_o => ctrl_o,                     -- O

  clk_10mhz => clk_10mhz,               -- I
  clk_pci => clk,                       -- I
  rst_n => rst_n,                       -- I

  -- Read Port

  rd_addr_i => rd_addr,                 -- I [10:0]
  rd_be_i => rd_be,                     -- I [3:0]
  rd_data_o => rd_data,                 -- O [31:0]

  -- Write Port

  wr_addr_i => wr_addr,                 -- I [10:0]
  wr_be_i => wr_be,                     -- I [7:0]
  wr_data_i => wr_data,                 -- I [31:0]
  wr_en_i => wr_en,                     -- I
  wr_busy_o => wr_busy                  -- O

);

EP_RX : PIO_RX_ENGINE port map (

  clk => clk,                           -- I
  rst_n => rst_n,                       -- I

  -- LocalLink Rx
  trn_rd => trn_rd,                     -- I [63:0]
  trn_rrem_n => trn_rrem_n,             -- I [7:0]
  trn_rsof_n => trn_rsof_n,             -- I
  trn_reof_n => trn_reof_n,             -- I
  trn_rsrc_rdy_n => trn_rsrc_rdy_n,     -- I
  trn_rsrc_dsc_n => trn_rsrc_dsc_n,     -- I
  trn_rbar_hit_n => trn_rbar_hit_n,     -- I [6:0]
  trn_rdst_rdy_n => trn_rdst_rdy_n,     -- O

  -- Handshake with Tx engine 

  req_compl_o => req_compl,             -- O
  compl_done_i => compl_done,           -- I

  req_tc_o => req_tc,                   -- O [2:0]
  req_td_o => req_td,                   -- O
  req_ep_o => req_ep,                   -- O
  req_attr_o => req_attr,               -- O [1:0]
  req_len_o => req_len,                 -- O [9:0]
  req_rid_o => req_rid,                 -- O [15:0]
  req_tag_o => req_tag,                 -- O [7:0]
  req_be_o => req_be,                   -- O [7:0]
  req_addr_o => req_addr,               -- O [12:0]

  -- Memory Write Port

  wr_addr_o => wr_addr,                 -- O [10:0]
  wr_be_o => wr_be,                     -- O [7:0]
  wr_data_o => wr_data,                 -- O [31:0]
  wr_en_o => wr_en,                     -- O
  wr_busy_i => wr_busy                  -- I
                   
);

-- Local-Link Transmit Controller

EP_TX : PIO_TX_ENGINE  port map (

  clk => clk,                         -- I
  rst_n => rst_n,                     -- I

  -- LocalLink Tx
  trn_td => trn_td,                   -- O [63:0]
  trn_trem_n => trn_trem_n    ,       -- O [7:0]
  trn_tsof_n => trn_tsof_n,           -- O
  trn_teof_n => trn_teof_n,           -- O
  trn_tsrc_dsc_n => trn_tsrc_dsc_n,   -- O
  trn_tsrc_rdy_n => trn_tsrc_rdy_n,   -- O
  trn_tdst_dsc_n => trn_tdst_dsc_n,   -- I
  trn_tdst_rdy_n => trn_tdst_rdy_n,   -- I

  -- Handshake with Rx engine 
  req_compl_i => req_compl,           -- I
  compl_done_o => compl_done,         -- 0

  req_tc_i => req_tc,                 -- I [2:0]
  req_td_i => req_td,                 -- I
  req_ep_i => req_ep,                 -- I
  req_attr_i => req_attr,             -- I [1:0]
  req_len_i => req_len,               -- I [9:0]
  req_rid_i => req_rid,               -- I [15:0]
  req_tag_i => req_tag,               -- I [7:0]
  req_be_i => req_be,                 -- I [7:0]
  req_addr_i => req_addr,             -- I [12:0]
                    
  -- Read Port

  rd_addr_o => rd_addr,              -- O [10:0]
  rd_be_o => rd_be,                  -- O [3:0]
  rd_data_i => rd_data,              -- I [31:0]

  completer_id_i => cfg_completer_id,          -- I [15:0]
  cfg_bus_mstr_enable_i => cfg_bus_mstr_enable -- I

);

  req_compl_o     <= req_compl;
  compl_done_o    <= compl_done;

end rtl; -- PIO_EP

