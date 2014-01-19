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
-- File       : xilinx_pcie_2_0_ep_v6.vhd
-- Version    : 1.7
--
-- Description: Top level (partially generate by Core Generator)
--
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.controller.all;

entity xilinx_pcie_2_0_ep_v6 is
  generic (
    PL_FAST_TRAIN : boolean := FALSE
  );
port (
  --
  -- User Inputs
  --
  user_clock                    : in std_logic;

  gpio_dip_sw                   : in std_logic_vector(8 downto 1);
  key_down                      : in std_logic;
  key_up                        : in std_logic;
  key_code                      : in std_logic_vector(5 downto 0);
                     
  --
  -- User Outputs
  --
  gpio_led_n                    : out std_logic;
  gpio_led                      : out std_logic_vector(7 downto 0);
  size_small                    : out std_logic;
  size_medium                   : out std_logic;
  unblank_left                  : out std_logic;
  unblank_right                 : out std_logic;
  pos_ver                       : out std_logic_vector(8 downto 0);
  pos_hor                       : out std_logic_vector(8 downto 0);
  hor_clk                       : out std_logic;
  ver_clk                       : out std_logic;
  hor_data                      : out std_logic_vector(7 downto 0);
  ver_data                      : out std_logic_vector(7 downto 0);

  --
  -- PCIe I/O
  --
  pci_exp_txp                   : out std_logic_vector(7 downto 0);
  pci_exp_txn                   : out std_logic_vector(7 downto 0);
  pci_exp_rxp                   : in std_logic_vector(7 downto 0);
  pci_exp_rxn                   : in std_logic_vector(7 downto 0);

  sys_clk_p                     : in std_logic;
  sys_clk_n                     : in std_logic;
  sys_reset_n                   : in std_logic
);
end xilinx_pcie_2_0_ep_v6;

architecture rtl of xilinx_pcie_2_0_ep_v6 is 

  component clock_10MHz
  port
   (
    CLK_IN1           : in     std_logic;
    CLK_OUT1          : out    std_logic;
    CLK_OUT1B         : out    std_logic
   );
  end component;

  component v6_pcie_v1_7 is
    generic (
      PL_FAST_TRAIN : boolean
    );
  port (
    pci_exp_txp                     : out std_logic_vector(7 downto 0);
    pci_exp_txn                     : out std_logic_vector(7 downto 0);
    pci_exp_rxp                     : in std_logic_vector(7 downto 0);
    pci_exp_rxn                     : in std_logic_vector(7 downto 0);
    trn_clk                         : out std_logic;
    trn_reset_n                     : out std_logic;
    trn_lnk_up_n                    : out std_logic;
    trn_tbuf_av                     : out std_logic_vector(5 downto 0);
    trn_tcfg_req_n                  : out std_logic;
    trn_terr_drop_n                 : out std_logic;
    trn_tdst_rdy_n                  : out std_logic;
    trn_td                          : in std_logic_vector(63 downto 0);
    trn_trem_n                      : in std_logic;
    trn_tsof_n                      : in std_logic;
    trn_teof_n                      : in std_logic;
    trn_tsrc_rdy_n                  : in std_logic;
    trn_tsrc_dsc_n                  : in std_logic;
    trn_terrfwd_n                   : in std_logic;
    trn_tcfg_gnt_n                  : in std_logic;
    trn_tstr_n                      : in std_logic;
    trn_rd                          : out std_logic_vector(63 downto 0);
    trn_rrem_n                      : out std_logic;
    trn_rsof_n                      : out std_logic;
    trn_reof_n                      : out std_logic;
    trn_rsrc_rdy_n                  : out std_logic;
    trn_rsrc_dsc_n                  : out std_logic;
    trn_rerrfwd_n                   : out std_logic;
    trn_rbar_hit_n                  : out std_logic_vector(6 downto 0);
    trn_rdst_rdy_n                  : in std_logic;
    trn_rnp_ok_n                    : in std_logic;
    trn_fc_cpld                     : out std_logic_vector(11 downto 0);
    trn_fc_cplh                     : out std_logic_vector(7 downto 0);
    trn_fc_npd                      : out std_logic_vector(11 downto 0);
    trn_fc_nph                      : out std_logic_vector(7 downto 0);
    trn_fc_pd                       : out std_logic_vector(11 downto 0);
    trn_fc_ph                       : out std_logic_vector(7 downto 0);
    trn_fc_sel                      : in std_logic_vector(2 downto 0);
    cfg_do                          : out std_logic_vector(31 downto 0);
    cfg_rd_wr_done_n                : out std_logic;
    cfg_di                          : in std_logic_vector(31 downto 0);
    cfg_byte_en_n                   : in std_logic_vector(3 downto 0);
    cfg_dwaddr                      : in std_logic_vector(9 downto 0);
    cfg_wr_en_n                     : in std_logic;
    cfg_rd_en_n                     : in std_logic;
    cfg_err_cor_n                   : in std_logic;
    cfg_err_ur_n                    : in std_logic;
    cfg_err_ecrc_n                  : in std_logic;
    cfg_err_cpl_timeout_n           : in std_logic;
    cfg_err_cpl_abort_n             : in std_logic;
    cfg_err_cpl_unexpect_n          : in std_logic;
    cfg_err_posted_n                : in std_logic;
    cfg_err_locked_n                : in std_logic;
    cfg_err_tlp_cpl_header          : in std_logic_vector(47 downto 0);
    cfg_err_cpl_rdy_n               : out std_logic;
    cfg_interrupt_n                 : in std_logic;
    cfg_interrupt_rdy_n             : out std_logic;
    cfg_interrupt_assert_n          : in std_logic;
    cfg_interrupt_di                : in std_logic_vector(7 downto 0);
    cfg_interrupt_do                : out std_logic_vector(7 downto 0);
    cfg_interrupt_mmenable          : out std_logic_vector(2 downto 0);
    cfg_interrupt_msienable         : out std_logic;
    cfg_interrupt_msixenable        : out std_logic;
    cfg_interrupt_msixfm            : out std_logic;
    cfg_turnoff_ok_n                : in std_logic;
    cfg_to_turnoff_n                : out std_logic;
    cfg_trn_pending_n               : in std_logic;
    cfg_pm_wake_n                   : in std_logic;
    cfg_bus_number                  : out std_logic_vector(7 downto 0);
    cfg_device_number               : out std_logic_vector(4 downto 0);
    cfg_function_number             : out std_logic_vector(2 downto 0);
    cfg_status                      : out std_logic_vector(15 downto 0);
    cfg_command                     : out std_logic_vector(15 downto 0);
    cfg_dstatus                     : out std_logic_vector(15 downto 0);
    cfg_dcommand                    : out std_logic_vector(15 downto 0);
    cfg_lstatus                     : out std_logic_vector(15 downto 0);
    cfg_lcommand                    : out std_logic_vector(15 downto 0);
    cfg_dcommand2                   : out std_logic_vector(15 downto 0);
    cfg_pcie_link_state_n           : out std_logic_vector(2 downto 0);
    cfg_dsn                         : in std_logic_vector(63 downto 0);
    cfg_pmcsr_pme_en                : out std_logic;
    cfg_pmcsr_pme_status            : out std_logic;
    cfg_pmcsr_powerstate            : out std_logic_vector(1 downto 0);
    pl_initial_link_width           : out std_logic_vector(2 downto 0);
    pl_lane_reversal_mode           : out std_logic_vector(1 downto 0);
    pl_link_gen2_capable            : out std_logic;
    pl_link_partner_gen2_supported  : out std_logic;
    pl_link_upcfg_capable           : out std_logic;
    pl_ltssm_state                  : out std_logic_vector(5 downto 0);
    pl_received_hot_rst             : out std_logic;
    pl_sel_link_rate                : out std_logic;
    pl_sel_link_width               : out std_logic_vector(1 downto 0);
    pl_directed_link_auton          : in std_logic;
    pl_directed_link_change         : in std_logic_vector(1 downto 0);
    pl_directed_link_speed          : in std_logic;
    pl_directed_link_width          : in std_logic_vector(1 downto 0);
    pl_upstream_prefer_deemph       : in std_logic;
    sys_clk                         : in std_logic;
    sys_reset_n                     : in std_logic);
  end component;

  component pcie_app_v6 is
  port  (
    ctrl_i                          : in controller_in;
    ctrl_o                          : out controller_out;
    clk_10mhz                       : in std_logic;
    trn_clk                         : in std_logic;
    trn_reset_n                     : in std_logic;
    trn_lnk_up_n                    : in std_logic;
    trn_td                          : out std_logic_vector(63 downto 0);
    trn_trem_n                      : out std_logic;
    trn_tsof_n                      : out std_logic;
    trn_teof_n                      : out std_logic;
    trn_tsrc_rdy_n                  : out std_logic;
    trn_tdst_rdy_n                  : in std_logic;
    trn_tsrc_dsc_n                  : out std_logic;
    trn_terrfwd_n                   : out std_logic;
    trn_tcfg_req_n                  : in std_logic;
    trn_tcfg_gnt_n                  : out std_logic;
    trn_terr_drop_n                 : in std_logic;
    trn_tbuf_av                     : in std_logic_vector(5 downto 0);
    trn_tstr_n                      : out std_logic;
    trn_rd                          : in std_logic_vector(63 downto 0);
    trn_rrem_n                      : in std_logic;
    trn_rsof_n                      : in std_logic;
    trn_reof_n                      : in std_logic;
    trn_rsrc_rdy_n                  : in std_logic;
    trn_rsrc_dsc_n                  : in std_logic;
    trn_rdst_rdy_n                  : out std_logic;
    trn_rerrfwd_n                   : in std_logic;
    trn_rnp_ok_n                    : out std_logic;
    trn_rbar_hit_n                  : in std_logic_vector(6 downto 0);
    trn_fc_nph                      : in std_logic_vector(7 downto 0);
    trn_fc_npd                      : in std_logic_vector(11 downto 0);
    trn_fc_ph                       : in std_logic_vector(7 downto 0);
    trn_fc_pd                       : in std_logic_vector(11 downto 0);
    trn_fc_cplh                     : in std_logic_vector(7 downto 0);
    trn_fc_cpld                     : in std_logic_vector(11 downto 0);
    trn_fc_sel                      : out std_logic_vector(2 downto 0);
    cfg_do                          : in std_logic_vector(31 downto 0);
    cfg_di                          : out std_logic_vector(31 downto 0);
    cfg_byte_en_n                   : out std_logic_vector(3 downto 0);
    cfg_dwaddr                      : out std_logic_vector(9 downto 0);
    cfg_rd_wr_done_n                : in std_logic;
    cfg_wr_en_n                     : out std_logic;
    cfg_rd_en_n                     : out std_logic;
    cfg_err_cor_n                   : out std_logic;
    cfg_err_ur_n                    : out std_logic;
    cfg_err_cpl_rdy_n               : in std_logic;
    cfg_err_ecrc_n                  : out std_logic;
    cfg_err_cpl_timeout_n           : out std_logic;
    cfg_err_cpl_abort_n             : out std_logic;
    cfg_err_cpl_unexpect_n          : out std_logic;
    cfg_err_posted_n                : out std_logic;
    cfg_err_locked_n                : out std_logic;
    cfg_interrupt_n                 : out std_logic;
    cfg_interrupt_rdy_n             : in std_logic;
    cfg_interrupt_assert_n          : out std_logic;
    cfg_interrupt_di                : out std_logic_vector(7 downto 0);
    cfg_interrupt_do                : in  std_logic_vector(7 downto 0);
    cfg_interrupt_mmenable          : in  std_logic_vector(2 downto 0);
    cfg_interrupt_msienable         : in  std_logic;
    cfg_interrupt_msixenable        : in  std_logic;
    cfg_interrupt_msixfm            : in  std_logic;
    cfg_turnoff_ok_n                : out std_logic;
    cfg_to_turnoff_n                : in std_logic;
    cfg_pm_wake_n                   : out std_logic;
    cfg_pcie_link_state_n           : in std_logic_vector(2 downto 0);
    cfg_trn_pending_n               : out std_logic;
    cfg_err_tlp_cpl_header          : out std_logic_vector(47 downto 0);
    cfg_bus_number                  : in std_logic_vector(7 downto 0);
    cfg_device_number               : in std_logic_vector(4 downto 0);
    cfg_function_number             : in std_logic_vector(2 downto 0);
    cfg_status                      : in std_logic_vector(15 downto 0);
    cfg_command                     : in std_logic_vector(15 downto 0);
    cfg_dstatus                     : in std_logic_vector(15 downto 0);
    cfg_dcommand                    : in std_logic_vector(15 downto 0);
    cfg_lstatus                     : in std_logic_vector(15 downto 0);
    cfg_lcommand                    : in std_logic_vector(15 downto 0);
    cfg_dcommand2                   : in std_logic_vector(15 downto 0);
    pl_directed_link_change         : out std_logic_vector(1 downto 0);
    pl_ltssm_state                  : in std_logic_vector(5 downto 0);
    pl_directed_link_width          : out std_logic_vector(1 downto 0);
    pl_directed_link_speed          : out std_logic;
    pl_directed_link_auton          : out std_logic;
    pl_upstream_prefer_deemph       : out std_logic;
    pl_sel_link_width               : in std_logic_vector(1 downto 0);
    pl_sel_link_rate                : in std_logic;
    pl_link_gen2_capable            : in std_logic;
    pl_link_partner_gen2_supported  : in std_logic;
    pl_initial_link_width           : in std_logic_vector(2 downto 0);
    pl_link_upcfg_capable           : in std_logic;
    pl_lane_reversal_mode           : in std_logic_vector(1 downto 0);
    pl_received_hot_rst             : in std_logic;
    cfg_dsn                         : out std_logic_vector(63 downto 0));
  end component;


  -- Tx
  signal trn_tbuf_av : std_logic_vector(5 downto 0);
  signal trn_tcfg_req_n : std_logic;
  signal trn_terr_drop_n : std_logic;
  signal trn_tdst_rdy_n : std_logic;
  signal trn_td : std_logic_vector(63 downto 0);
  signal trn_trem_n : std_logic;
  signal trn_tsof_n : std_logic;
  signal trn_teof_n : std_logic;
  signal trn_tsrc_rdy_n : std_logic;
  signal trn_tsrc_dsc_n : std_logic;
  signal trn_terrfwd_n : std_logic;
  signal trn_tcfg_gnt_n : std_logic;
  signal trn_tstr_n : std_logic;

  -- Rx
  signal trn_rd : std_logic_vector(63 downto 0);
  signal trn_rrem_n : std_logic;
  signal trn_rsof_n : std_logic;
  signal trn_reof_n : std_logic;
  signal trn_rsrc_rdy_n : std_logic;
  signal trn_rsrc_dsc_n : std_logic;
  signal trn_rerrfwd_n : std_logic;
  signal trn_rbar_hit_n : std_logic_vector(6 downto 0);
  signal trn_rdst_rdy_n : std_logic;
  signal trn_rnp_ok_n : std_logic;

  -- Flow Control
  signal trn_fc_cpld : std_logic_vector(11 downto 0);
  signal trn_fc_cplh : std_logic_vector(7 downto 0);
  signal trn_fc_npd : std_logic_vector(11 downto 0);
  signal trn_fc_nph : std_logic_vector(7 downto 0);
  signal trn_fc_pd : std_logic_vector(11 downto 0);
  signal trn_fc_ph : std_logic_vector(7 downto 0);
  signal trn_fc_sel : std_logic_vector(2 downto 0);

  signal trn_lnk_up_n : std_logic;
  signal trn_lnk_up_n_int1 : std_logic;
  signal trn_clk : std_logic;
  signal trn_reset_n : std_logic;
  signal trn_reset_n_int1 : std_logic;

  ---------------------------------------------------------
  -- 3. Configuration (CFG) Interface
  ---------------------------------------------------------

  signal cfg_do : std_logic_vector(31 downto 0);
  signal cfg_rd_wr_done_n : std_logic;
  signal cfg_di : std_logic_vector(31 downto 0);
  signal cfg_byte_en_n : std_logic_vector(3 downto 0);
  signal cfg_dwaddr : std_logic_vector(9 downto 0);
  signal cfg_wr_en_n : std_logic;
  signal cfg_rd_en_n : std_logic;

  signal cfg_err_cor_n: std_logic;
  signal cfg_err_ur_n : std_logic;
  signal cfg_err_ecrc_n : std_logic;
  signal cfg_err_cpl_timeout_n : std_logic;
  signal cfg_err_cpl_abort_n : std_logic;
  signal cfg_err_cpl_unexpect_n : std_logic;
  signal cfg_err_posted_n : std_logic;
  signal cfg_err_locked_n : std_logic;
  signal cfg_err_tlp_cpl_header : std_logic_vector(47 downto 0);
  signal cfg_err_cpl_rdy_n : std_logic;
  signal cfg_interrupt_n : std_logic;
  signal cfg_interrupt_rdy_n : std_logic;
  signal cfg_interrupt_assert_n : std_logic;
  signal cfg_interrupt_di : std_logic_vector(7 downto 0);
  signal cfg_interrupt_do : std_logic_vector(7 downto 0);
  signal cfg_interrupt_mmenable : std_logic_vector(2 downto 0);
  signal cfg_interrupt_msienable : std_logic;
  signal cfg_interrupt_msixenable : std_logic;
  signal cfg_interrupt_msixfm : std_logic;
  signal cfg_turnoff_ok_n : std_logic;
  signal cfg_to_turnoff_n : std_logic;
  signal cfg_trn_pending_n : std_logic;
  signal cfg_pm_wake_n : std_logic;
  signal cfg_bus_number : std_logic_vector(7 downto 0);
  signal cfg_device_number : std_logic_vector(4 downto 0);
  signal cfg_function_number : std_logic_vector(2 downto 0);
  signal cfg_status : std_logic_vector(15 downto 0);
  signal cfg_command : std_logic_vector(15 downto 0);
  signal cfg_dstatus : std_logic_vector(15 downto 0);
  signal cfg_dcommand : std_logic_vector(15 downto 0);
  signal cfg_lstatus : std_logic_vector(15 downto 0);
  signal cfg_lcommand : std_logic_vector(15 downto 0);
  signal cfg_dcommand2 : std_logic_vector(15 downto 0);
  signal cfg_pcie_link_state_n : std_logic_vector(2 downto 0);
  signal cfg_dsn : std_logic_vector(63 downto 0);

  ---------------------------------------------------------
  -- 4. Physical Layer Control and Status (PL) Interface
  ---------------------------------------------------------

  signal pl_initial_link_width : std_logic_vector(2 downto 0);
  signal pl_lane_reversal_mode : std_logic_vector(1 downto 0);
  signal pl_link_gen2_capable : std_logic;
  signal pl_link_partner_gen2_supported : std_logic;
  signal pl_link_upcfg_capable : std_logic;
  signal pl_ltssm_state : std_logic_vector(5 downto 0);
  signal pl_received_hot_rst : std_logic;
  signal pl_sel_link_rate : std_logic;
  signal pl_sel_link_width : std_logic_vector(1 downto 0);
  signal pl_directed_link_auton : std_logic;
  signal pl_directed_link_change : std_logic_vector(1 downto 0);
  signal pl_directed_link_speed : std_logic;
  signal pl_directed_link_width : std_logic_vector(1 downto 0);
  signal pl_upstream_prefer_deemph : std_logic;

  signal sys_clk_c : std_logic;
  signal sys_reset_n_c : std_logic;

  signal ctrl_i : controller_in;
  signal ctrl_o : controller_out;

  signal clk_10mhz : std_logic;
  signal clk_dac : std_logic;
  signal count : integer range 0 to 2**24 := 0;
  signal blink_led : std_logic := '0';

  -------------------------------------------------------

begin

  --              
  -- Blink at 1 Hz
  --              
  process (clk_10mhz, sys_reset_n_c)
  variable c : integer range 0 to 2**24;
  begin
    if (sys_reset_n_c = '0') then
      count <= 0;
      blink_led <= '0';
    elsif (rising_edge(clk_10mhz)) then
      c := count;
      if (c = 5000000) then
        c := 0;
        blink_led <= NOT blink_led;
      else
        c := c + 1;
      end if;
      count <= c;
    end if;
  end process;

  --              
  -- User Inputs  
  --              
  ctrl_i.gpio_dip_sw <= gpio_dip_sw;
  ctrl_i.key_down    <= key_down;
  ctrl_i.key_up      <= key_up;
  ctrl_i.key_code    <= key_code;
                  
  --              
  -- User Outputs 
  --              
  gpio_led_n         <= blink_led;
  gpio_led           <= ctrl_o.gpio_led;     
  size_small         <= ctrl_o.size_small;   
  size_medium        <= ctrl_o.size_medium;  
  unblank_left       <= ctrl_o.unblank_left; 
  unblank_right      <= ctrl_o.unblank_right;
  pos_ver            <= ctrl_o.pos_ver;      
  pos_hor            <= ctrl_o.pos_hor;      
  hor_clk            <= clk_dac;
  ver_clk            <= clk_dac;
  hor_data           <= ctrl_o.h_deflection & "00000";
  ver_data           <= ctrl_o.v_deflection & "00000";

  --              
  -- Instantiate modules
  --              
  controller_clock : clock_10MHz
    port map
    (
      CLK_IN1   => user_clock,
      CLK_OUT1  => clk_10mhz,
      CLK_OUT1B => clk_dac
    );

  refclk_ibuf : IBUFDS_GTXE1 
     port map(
       O        => sys_clk_c,
       ODIV2    => open,
       I        => sys_clk_p,
       IB       => sys_clk_n,
       CEB      => '0');

  sys_reset_n_ibuf : IBUF
     port map(
       O        => sys_reset_n_c,
       I        => sys_reset_n);

  trn_lnk_up_n_int_i: FDCP
     generic map(
       INIT     => '1')
     port map(  
       Q        => trn_lnk_up_n,
       D        => trn_lnk_up_n_int1,
       C        => trn_clk,
       CLR      => '0',
       PRE      => '0');

  trn_reset_n_i : FDCP 
     generic map(
       INIT     => '1')
     port map(
        Q       => trn_reset_n,
        D       => trn_reset_n_int1,
        C       => trn_clk,
        CLR     => '0',
        PRE     => '0');


  core_i : v6_pcie_v1_7 
    generic map( 
       PL_FAST_TRAIN => PL_FAST_TRAIN)
    port map(
    pci_exp_txp                     =>  pci_exp_txp,
    pci_exp_txn                     =>  pci_exp_txn,
    pci_exp_rxp                     =>  pci_exp_rxp,
    pci_exp_rxn                     =>  pci_exp_rxn,
    trn_clk                         =>  trn_clk ,
    trn_reset_n                     =>  trn_reset_n_int1 ,
    trn_lnk_up_n                    =>  trn_lnk_up_n_int1 ,
    trn_tbuf_av                     =>  trn_tbuf_av ,
    trn_tcfg_req_n                  =>  trn_tcfg_req_n ,
    trn_terr_drop_n                 =>  trn_terr_drop_n ,
    trn_tdst_rdy_n                  =>  trn_tdst_rdy_n ,
    trn_td                          =>  trn_td ,
    trn_trem_n                      =>  trn_trem_n ,
    trn_tsof_n                      =>  trn_tsof_n ,
    trn_teof_n                      =>  trn_teof_n ,
    trn_tsrc_rdy_n                  =>  trn_tsrc_rdy_n ,
    trn_tsrc_dsc_n                  =>  trn_tsrc_dsc_n ,
    trn_terrfwd_n                   =>  trn_terrfwd_n ,
    trn_tcfg_gnt_n                  =>  trn_tcfg_gnt_n ,
    trn_tstr_n                      =>  trn_tstr_n ,
    trn_rd                          =>  trn_rd ,
    trn_rrem_n                      =>  trn_rrem_n ,
    trn_rsof_n                      =>  trn_rsof_n ,
    trn_reof_n                      =>  trn_reof_n ,
    trn_rsrc_rdy_n                  =>  trn_rsrc_rdy_n ,
    trn_rsrc_dsc_n                  =>  trn_rsrc_dsc_n ,
    trn_rerrfwd_n                   =>  trn_rerrfwd_n ,
    trn_rbar_hit_n                  =>  trn_rbar_hit_n ,
    trn_rdst_rdy_n                  =>  trn_rdst_rdy_n ,
    trn_rnp_ok_n                    =>  trn_rnp_ok_n ,
    trn_fc_cpld                     =>  trn_fc_cpld ,
    trn_fc_cplh                     =>  trn_fc_cplh ,
    trn_fc_npd                      =>  trn_fc_npd ,
    trn_fc_nph                      =>  trn_fc_nph ,
    trn_fc_pd                       =>  trn_fc_pd ,
    trn_fc_ph                       =>  trn_fc_ph ,
    trn_fc_sel                      =>  trn_fc_sel ,
    cfg_do                          =>  cfg_do ,
    cfg_rd_wr_done_n                =>  cfg_rd_wr_done_n,
    cfg_di                          =>  cfg_di ,
    cfg_byte_en_n                   =>  cfg_byte_en_n ,
    cfg_dwaddr                      =>  cfg_dwaddr ,
    cfg_wr_en_n                     =>  cfg_wr_en_n ,
    cfg_rd_en_n                     =>  cfg_rd_en_n ,
    cfg_err_cor_n                   =>  cfg_err_cor_n ,
    cfg_err_ur_n                    =>  cfg_err_ur_n ,
    cfg_err_ecrc_n                  =>  cfg_err_ecrc_n ,
    cfg_err_cpl_timeout_n           =>  cfg_err_cpl_timeout_n ,
    cfg_err_cpl_abort_n             =>  cfg_err_cpl_abort_n ,
    cfg_err_cpl_unexpect_n          =>  cfg_err_cpl_unexpect_n ,
    cfg_err_posted_n                =>  cfg_err_posted_n ,
    cfg_err_locked_n                =>  cfg_err_locked_n ,
    cfg_err_tlp_cpl_header          =>  cfg_err_tlp_cpl_header ,
    cfg_err_cpl_rdy_n               =>  cfg_err_cpl_rdy_n ,
    cfg_interrupt_n                 =>  cfg_interrupt_n ,
    cfg_interrupt_rdy_n             =>  cfg_interrupt_rdy_n ,
    cfg_interrupt_assert_n          =>  cfg_interrupt_assert_n ,
    cfg_interrupt_di                =>  cfg_interrupt_di ,
    cfg_interrupt_do                =>  cfg_interrupt_do ,
    cfg_interrupt_mmenable          =>  cfg_interrupt_mmenable ,
    cfg_interrupt_msienable         =>  cfg_interrupt_msienable ,
    cfg_interrupt_msixenable        =>  cfg_interrupt_msixenable ,
    cfg_interrupt_msixfm            =>  cfg_interrupt_msixfm ,
    cfg_turnoff_ok_n                =>  cfg_turnoff_ok_n ,
    cfg_to_turnoff_n                =>  cfg_to_turnoff_n ,
    cfg_trn_pending_n               =>  cfg_trn_pending_n ,
    cfg_pm_wake_n                   =>  cfg_pm_wake_n ,
    cfg_bus_number                  =>  cfg_bus_number ,
    cfg_device_number               =>  cfg_device_number ,
    cfg_function_number             =>  cfg_function_number ,
    cfg_status                      =>  cfg_status ,
    cfg_command                     =>  cfg_command ,
    cfg_dstatus                     =>  cfg_dstatus ,
    cfg_dcommand                    =>  cfg_dcommand ,
    cfg_lstatus                     =>  cfg_lstatus ,
    cfg_lcommand                    =>  cfg_lcommand ,
    cfg_dcommand2                   =>  cfg_dcommand2 ,
    cfg_pcie_link_state_n           =>  cfg_pcie_link_state_n ,
    cfg_dsn                         =>  cfg_dsn ,
    cfg_pmcsr_pme_en                =>  open,
    cfg_pmcsr_pme_status            =>  open,
    cfg_pmcsr_powerstate            =>  open,
    pl_initial_link_width           =>  pl_initial_link_width ,
    pl_lane_reversal_mode           =>  pl_lane_reversal_mode ,
    pl_link_gen2_capable            =>  pl_link_gen2_capable ,
    pl_link_partner_gen2_supported  =>  pl_link_partner_gen2_supported ,
    pl_link_upcfg_capable           =>  pl_link_upcfg_capable ,
    pl_ltssm_state                  =>  pl_ltssm_state ,
    pl_received_hot_rst             =>  pl_received_hot_rst ,
    pl_sel_link_rate                =>  pl_sel_link_rate ,
    pl_sel_link_width               =>  pl_sel_link_width ,
    pl_directed_link_auton          =>  pl_directed_link_auton ,
    pl_directed_link_change         =>  pl_directed_link_change ,
    pl_directed_link_speed          =>  pl_directed_link_speed ,
    pl_directed_link_width          =>  pl_directed_link_width ,
    pl_upstream_prefer_deemph       =>  pl_upstream_prefer_deemph ,
    sys_clk                         =>  sys_clk_c ,
    sys_reset_n                     =>  sys_reset_n_c 
  );

  app : pcie_app_v6
    port map(
    ctrl_i                          =>  ctrl_i ,
    ctrl_o                          =>  ctrl_o,
    clk_10mhz                       =>  clk_10mhz,
    trn_clk                         =>  trn_clk ,
    trn_reset_n                     =>  trn_reset_n_int1 ,
    trn_lnk_up_n                    =>  trn_lnk_up_n_int1 ,
    trn_tbuf_av                     =>  trn_tbuf_av ,
    trn_tcfg_req_n                  =>  trn_tcfg_req_n ,
    trn_terr_drop_n                 =>  trn_terr_drop_n ,
    trn_tdst_rdy_n                  =>  trn_tdst_rdy_n ,
    trn_td                          =>  trn_td ,
    trn_trem_n                      =>  trn_trem_n ,
    trn_tsof_n                      =>  trn_tsof_n ,
    trn_teof_n                      =>  trn_teof_n ,
    trn_tsrc_rdy_n                  =>  trn_tsrc_rdy_n ,
    trn_tsrc_dsc_n                  =>  trn_tsrc_dsc_n ,
    trn_terrfwd_n                   =>  trn_terrfwd_n ,
    trn_tcfg_gnt_n                  =>  trn_tcfg_gnt_n ,
    trn_tstr_n                      =>  trn_tstr_n ,
    trn_rd                          =>  trn_rd ,
    trn_rrem_n                      =>  trn_rrem_n ,
    trn_rsof_n                      =>  trn_rsof_n ,
    trn_reof_n                      =>  trn_reof_n ,
    trn_rsrc_rdy_n                  =>  trn_rsrc_rdy_n ,
    trn_rsrc_dsc_n                  =>  trn_rsrc_dsc_n ,
    trn_rerrfwd_n                   =>  trn_rerrfwd_n ,
    trn_rbar_hit_n                  =>  trn_rbar_hit_n ,
    trn_rdst_rdy_n                  =>  trn_rdst_rdy_n ,
    trn_rnp_ok_n                    =>  trn_rnp_ok_n ,
    trn_fc_cpld                     =>  trn_fc_cpld ,
    trn_fc_cplh                     =>  trn_fc_cplh ,
    trn_fc_npd                      =>  trn_fc_npd ,
    trn_fc_nph                      =>  trn_fc_nph ,
    trn_fc_pd                       =>  trn_fc_pd ,
    trn_fc_ph                       =>  trn_fc_ph ,
    trn_fc_sel                      =>  trn_fc_sel ,
    cfg_do                          =>  cfg_do ,
    cfg_rd_wr_done_n                =>  cfg_rd_wr_done_n,
    cfg_di                          =>  cfg_di ,
    cfg_byte_en_n                   =>  cfg_byte_en_n ,
    cfg_dwaddr                      =>  cfg_dwaddr ,
    cfg_wr_en_n                     =>  cfg_wr_en_n ,
    cfg_rd_en_n                     =>  cfg_rd_en_n ,
    cfg_err_cor_n                   =>  cfg_err_cor_n ,
    cfg_err_ur_n                    =>  cfg_err_ur_n ,
    cfg_err_ecrc_n                  =>  cfg_err_ecrc_n ,
    cfg_err_cpl_timeout_n           =>  cfg_err_cpl_timeout_n ,
    cfg_err_cpl_abort_n             =>  cfg_err_cpl_abort_n ,
    cfg_err_cpl_unexpect_n          =>  cfg_err_cpl_unexpect_n ,
    cfg_err_posted_n                =>  cfg_err_posted_n ,
    cfg_err_locked_n                =>  cfg_err_locked_n ,
    cfg_err_tlp_cpl_header          =>  cfg_err_tlp_cpl_header ,
    cfg_err_cpl_rdy_n               =>  cfg_err_cpl_rdy_n ,
    cfg_interrupt_n                 =>  cfg_interrupt_n ,
    cfg_interrupt_rdy_n             =>  cfg_interrupt_rdy_n ,
    cfg_interrupt_assert_n          =>  cfg_interrupt_assert_n ,
    cfg_interrupt_di                =>  cfg_interrupt_di ,
    cfg_interrupt_do                =>  cfg_interrupt_do ,
    cfg_interrupt_mmenable          =>  cfg_interrupt_mmenable ,
    cfg_interrupt_msienable         =>  cfg_interrupt_msienable ,
    cfg_interrupt_msixenable        =>  cfg_interrupt_msixenable ,
    cfg_interrupt_msixfm            =>  cfg_interrupt_msixfm ,
    cfg_turnoff_ok_n                =>  cfg_turnoff_ok_n ,
    cfg_to_turnoff_n                =>  cfg_to_turnoff_n ,
    cfg_trn_pending_n               =>  cfg_trn_pending_n ,
    cfg_pm_wake_n                   =>  cfg_pm_wake_n ,
    cfg_bus_number                  =>  cfg_bus_number ,
    cfg_device_number               =>  cfg_device_number ,
    cfg_function_number             =>  cfg_function_number ,
    cfg_status                      =>  cfg_status ,
    cfg_command                     =>  cfg_command ,
    cfg_dstatus                     =>  cfg_dstatus ,
    cfg_dcommand                    =>  cfg_dcommand ,
    cfg_lstatus                     =>  cfg_lstatus ,
    cfg_lcommand                    =>  cfg_lcommand ,
    cfg_dcommand2                   =>  cfg_dcommand2 ,
    cfg_pcie_link_state_n           =>  cfg_pcie_link_state_n ,
    cfg_dsn                         =>  cfg_dsn ,
    pl_initial_link_width           =>  pl_initial_link_width ,
    pl_lane_reversal_mode           =>  pl_lane_reversal_mode ,
    pl_link_gen2_capable            =>  pl_link_gen2_capable ,
    pl_link_partner_gen2_supported  =>  pl_link_partner_gen2_supported ,
    pl_link_upcfg_capable           =>  pl_link_upcfg_capable ,
    pl_ltssm_state                  =>  pl_ltssm_state ,
    pl_received_hot_rst             =>  pl_received_hot_rst ,
    pl_sel_link_rate                =>  pl_sel_link_rate ,
    pl_sel_link_width               =>  pl_sel_link_width ,
    pl_directed_link_auton          =>  pl_directed_link_auton ,
    pl_directed_link_change         =>  pl_directed_link_change ,
    pl_directed_link_speed          =>  pl_directed_link_speed ,
    pl_directed_link_width          =>  pl_directed_link_width ,
    pl_upstream_prefer_deemph       =>  pl_upstream_prefer_deemph
  );
  
end rtl;
