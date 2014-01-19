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
-- File       : pcie_app_v6.vhd
-- Version    : 1.7
--
-- Description:  PCI Express Endpoint Core application.
--
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;

use work.controller.all;

entity pcie_app_v6 is

port  (
  ctrl_i                    : in controller_in;
  ctrl_o                    : out controller_out;

  clk_10mhz                 : in std_logic;

  -- Common

  trn_clk                   : in std_logic;
  trn_reset_n               : in std_logic;
  trn_lnk_up_n              : in std_logic;

  -- Tx

  trn_td                    : out std_logic_vector(63 downto 0);
  trn_trem_n                : out std_logic;
  trn_tsof_n                : out std_logic;
  trn_teof_n                : out std_logic;
  trn_tsrc_rdy_n            : out std_logic;
  trn_tdst_rdy_n            : in std_logic;
  trn_tsrc_dsc_n            : out std_logic;
  trn_terrfwd_n             : out std_logic;
  trn_tcfg_req_n            : in std_logic;
  trn_tcfg_gnt_n            : out std_logic;
  trn_terr_drop_n           : in std_logic;
  trn_tbuf_av               : in std_logic_vector(5 downto 0);
  trn_tstr_n                : out std_logic;

  -- Rx

  trn_rd                    : in std_logic_vector(63 downto 0);
  trn_rrem_n                : in std_logic;
  trn_rsof_n                : in std_logic;
  trn_reof_n                : in std_logic;
  trn_rsrc_rdy_n            : in std_logic;
  trn_rsrc_dsc_n            : in std_logic;
  trn_rdst_rdy_n            : out std_logic;
  trn_rerrfwd_n             : in std_logic;
  trn_rnp_ok_n              : out std_logic;
  trn_rbar_hit_n            : in std_logic_vector(6 downto 0);
  trn_fc_nph                : in std_logic_vector(7 downto 0);
  trn_fc_npd                : in std_logic_vector(11 downto 0);
  trn_fc_ph                 : in std_logic_vector(7 downto 0);
  trn_fc_pd                 : in std_logic_vector(11 downto 0);
  trn_fc_cplh               : in std_logic_vector(7 downto 0);
  trn_fc_cpld               : in std_logic_vector(11 downto 0);
  trn_fc_sel                : out std_logic_vector(2 downto 0);

  -- Host (CFG) Interface

  cfg_do                    : in std_logic_vector(31 downto 0);
  cfg_di                    : out std_logic_vector(31 downto 0);
  cfg_byte_en_n             : out std_logic_vector(3 downto 0);
  cfg_dwaddr                : out std_logic_vector(9 downto 0);
  cfg_rd_wr_done_n          : in std_logic;
  cfg_wr_en_n               : out std_logic;
  cfg_rd_en_n               : out std_logic;
  cfg_err_cor_n             : out std_logic;
  cfg_err_ur_n              : out std_logic;
  cfg_err_cpl_rdy_n         : in std_logic;
  cfg_err_ecrc_n            : out std_logic;
  cfg_err_cpl_timeout_n     : out std_logic;
  cfg_err_cpl_abort_n       : out std_logic;
  cfg_err_cpl_unexpect_n    : out std_logic;
  cfg_err_posted_n          : out std_logic;
  cfg_err_locked_n          : out std_logic;
  cfg_interrupt_n           : out std_logic;
  cfg_interrupt_rdy_n       : in std_logic;

  cfg_interrupt_assert_n    : out std_logic;
  cfg_interrupt_di          : out std_logic_vector(7 downto 0);
  cfg_interrupt_do          : in  std_logic_vector(7 downto 0);
  cfg_interrupt_mmenable    : in  std_logic_vector(2 downto 0);
  cfg_interrupt_msienable   : in  std_logic;
  cfg_interrupt_msixenable  : in  std_logic;
  cfg_interrupt_msixfm      : in  std_logic;

  cfg_turnoff_ok_n          : out std_logic;
  cfg_to_turnoff_n          : in std_logic;
  cfg_pm_wake_n             : out std_logic;
  cfg_pcie_link_state_n     : in std_logic_vector(2 downto 0);
  cfg_trn_pending_n         : out std_logic;
  cfg_err_tlp_cpl_header    : out std_logic_vector(47 downto 0);
  cfg_bus_number            : in std_logic_vector(7 downto 0);
  cfg_device_number         : in std_logic_vector(4 downto 0);
  cfg_function_number       : in std_logic_vector(2 downto 0);
  cfg_status                : in std_logic_vector(15 downto 0);
  cfg_command               : in std_logic_vector(15 downto 0);
  cfg_dstatus               : in std_logic_vector(15 downto 0);
  cfg_dcommand              : in std_logic_vector(15 downto 0);
  cfg_lstatus               : in std_logic_vector(15 downto 0);
  cfg_lcommand              : in std_logic_vector(15 downto 0);
  cfg_dcommand2             : in std_logic_vector(15 downto 0);

  pl_directed_link_change   : out std_logic_vector(1 downto 0);
  pl_ltssm_state            : in std_logic_vector(5 downto 0);
  pl_directed_link_width    : out std_logic_vector(1 downto 0);
  pl_directed_link_speed    : out std_logic;
  pl_directed_link_auton    : out std_logic;
  pl_upstream_prefer_deemph : out std_logic;
  
  pl_sel_link_width         : in std_logic_vector(1 downto 0);
  pl_sel_link_rate          : in std_logic;
  pl_link_gen2_capable      : in std_logic;
  pl_link_partner_gen2_supported : in std_logic;
  pl_initial_link_width     : in std_logic_vector(2 downto 0);
  pl_link_upcfg_capable     : in std_logic;
  pl_lane_reversal_mode     : in std_logic_vector(1 downto 0);
  pl_received_hot_rst       : in std_logic;

  cfg_dsn                   : out std_logic_vector(63 downto 0)

);
end pcie_app_v6;

architecture v6_pcie of pcie_app_v6 is

component PIO
port (
  ctrl_i                 : in controller_in;
  ctrl_o                 : out controller_out;
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
  cfg_bus_mstr_enable    : in std_logic);

end component;

-- Local wires 

signal cfg_completer_id       : std_logic_vector(15 downto 0);
signal cfg_bus_mstr_enable    : std_logic;
signal trn_trem_n_out         : std_logic_vector(7 downto 0);
signal trn_rrem_n_in          : std_logic_vector(7 downto 0);

begin 

  -- Core input tie-offs

  trn_rnp_ok_n              <= '0';
  trn_terrfwd_n             <= '1';
  trn_fc_sel                <= "000";
  trn_tcfg_gnt_n            <= '0';
  trn_tstr_n                <= '0';

  pl_directed_link_change   <= "00";
  pl_directed_link_width    <= "00";
  pl_directed_link_speed    <= '0';
  pl_directed_link_auton    <= '0';
  pl_upstream_prefer_deemph <= '1';

  cfg_err_cor_n             <= '1';
  cfg_err_ur_n              <= '1';
  cfg_err_ecrc_n            <= '1';
  cfg_err_cpl_timeout_n     <= '1';
  cfg_err_cpl_abort_n       <= '1';
  cfg_err_cpl_unexpect_n    <= '1';
  cfg_err_posted_n          <= '0';
  cfg_err_locked_n          <= '1';

  cfg_interrupt_n           <= '1';
  cfg_interrupt_assert_n    <= '0';
  cfg_interrupt_di          <= X"00";

  cfg_pm_wake_n             <= '1';
  cfg_trn_pending_n         <= '1';
  cfg_dwaddr                <= (others => '0');
  cfg_err_tlp_cpl_header    <= (others => '0');
  cfg_di                    <= (others => '0');
  cfg_byte_en_n             <= X"F"; -- 4-bit bus
  cfg_wr_en_n               <= '1';
  cfg_rd_en_n               <= '1';
  cfg_dsn                   <= X"0000000101000A35";

  cfg_completer_id          <= (cfg_bus_number &
                                cfg_device_number &
                                cfg_function_number);
  cfg_bus_mstr_enable       <= cfg_command(2);

  trn_trem_n                <= '1' when (trn_trem_n_out = X"0F") else
                               '0';
  trn_rrem_n_in             <= X"0F" when (trn_rrem_n = '1') else
                               X"00";

-- Programmable I/O Module

PIO_interface : PIO 

port map (
  ctrl_i  => ctrl_i ,                         -- I
  ctrl_o  => ctrl_o,                          -- O
  
  clk_10mhz => clk_10mhz,                     -- I     

  trn_clk  =>  trn_clk,                       -- I
  trn_reset_n  =>  trn_reset_n,               -- I
  trn_lnk_up_n  =>  trn_lnk_up_n,             -- I

  trn_td  => trn_td,                          -- O (63:0)
  trn_tsof_n  => trn_tsof_n,
  trn_trem_n  => trn_trem_n_out,
  trn_teof_n  => trn_teof_n,                  -- O
  trn_tsrc_rdy_n  => trn_tsrc_rdy_n,          -- O
  trn_tsrc_dsc_n  => trn_tsrc_dsc_n,          -- O
  trn_tdst_rdy_n  => trn_tdst_rdy_n,          -- I
  trn_tdst_dsc_n  => '1',                     -- I

  trn_rd  => trn_rd ,                         -- I (63:0)
  trn_rrem_n  => trn_rrem_n_in,
  trn_rsof_n  => trn_rsof_n,                  -- I
  trn_reof_n  => trn_reof_n,                  -- I
  trn_rsrc_rdy_n  => trn_rsrc_rdy_n,          -- I
  trn_rsrc_dsc_n  => trn_rsrc_dsc_n,          -- I
  trn_rbar_hit_n => trn_rbar_hit_n,           -- I (6:0)
  trn_rdst_rdy_n  => trn_rdst_rdy_n,          -- O

  cfg_to_turnoff_n  => cfg_to_turnoff_n,      -- I
  cfg_turnoff_ok_n => cfg_turnoff_ok_n,    -- O
  cfg_completer_id  => cfg_completer_id,      -- I (15:0)
  cfg_bus_mstr_enable => cfg_bus_mstr_enable  -- I

);

end; -- pcie_app_v6
