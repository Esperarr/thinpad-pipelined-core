// `include "package.svh"
module thinpad_top (
    input wire clk_50M,     // 50MHz ???????
    input wire clk_11M0592, // 11.0592MHz ??????????????????

    input wire push_btn,  // BTN5 ????????????????��???????? 1
    input wire reset_btn, // BTN6 ??��?????????????��???????? 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4???????????????? 1
    input  wire [31:0] dip_sw,     // 32 ��?????????????ON???? 1
    output wire [15:0] leds,       // 16 �� LED?????? 1 ????
    output wire [ 7:0] dpy0,       // ??????��????????��??????? 1 ????
    output wire [ 7:0] dpy1,       // ??????��????????��??????? 1 ????

    // CPLD ????????????
    output wire uart_rdn,        // ??????????????��
    output wire uart_wrn,        // ��????????????��
    input  wire uart_dataready,  // ?????????????
    input  wire uart_tbre,       // ??????????
    input  wire uart_tsre,       // ????????????

    // BaseRAM ???
    inout wire [31:0] base_ram_data,  // BaseRAM ??????? 8 ��?? CPLD ?????????????
    output wire [19:0] base_ram_addr,  // BaseRAM ???
    output wire [3:0] base_ram_be_n,  // BaseRAM ???????????��?????????????????????? 0
    output wire base_ram_ce_n,  // BaseRAM ????????��
    output wire base_ram_oe_n,  // BaseRAM ??????????��
    output wire base_ram_we_n,  // BaseRAM ��????????��

    // ExtRAM ???
    inout wire [31:0] ext_ram_data,  // ExtRAM ????
    output wire [19:0] ext_ram_addr,  // ExtRAM ???
    output wire [3:0] ext_ram_be_n,  // ExtRAM ???????????��?????????????????????? 0
    output wire ext_ram_ce_n,  // ExtRAM ????????��
    output wire ext_ram_oe_n,  // ExtRAM ??????????��
    output wire ext_ram_we_n,  // ExtRAM ��????????��

    // ??????????
    output wire txd,  // ???????????
    input  wire rxd,  // ???????????

    // Flash ?��???????��? JS28F640 ��????
    output wire [22:0] flash_a,  // Flash ?????a0 ???? 8bit ????��??16bit ????????
    inout wire [15:0] flash_d,  // Flash ????
    output wire flash_rp_n,  // Flash ??��????????��
    output wire flash_vpen,  // Flash ��????????????????????????��
    output wire flash_ce_n,  // Flash ??????????��
    output wire flash_oe_n,  // Flash ?????????????��
    output wire flash_we_n,  // Flash ��???????????��
    output wire flash_byte_n, // Flash 8bit ????????��??????? flash ?? 16 ��???????? 1

    // USB ???????????��? SL811 ��????
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB ??????????????????? dm9k_sd[7:0] ????
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // ??????????????��? DM9000A ��????
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // ?????????
    output wire [2:0] video_red,    // ????????3 ��
    output wire [2:0] video_green,  // ????????3 ��
    output wire [1:0] video_blue,   // ????????2 ��
    output wire       video_hsync,  // ?????????????????
    output wire       video_vsync,  // ??????????????????
    output wire       video_clk,    // ??????????
    output wire       video_de      // ????????��??????????????????
);

  /* =========== Demo code begin =========== */

  // PLL ??????
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // ?????????
      // Clock out ports
      .clk_out1(clk_10M),  // ?????? 1??????? IP ?????????????
      .clk_out2(clk_20M),  // ?????? 2??????? IP ?????????????
      // Status and control signals
      .reset(reset_btn),  // PLL ??��????
      .locked(locked)  // PLL ???????????"1"???????????
                       // ???��??��????????????????????
  );

  logic reset_of_clk10M;
  logic reset_of_clk20M;
  logic reset_of_clk50M;
  // ????��??????????? locked ????????��???�� reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  always_ff @(posedge clk_50M or negedge locked) begin
    if (~locked) reset_of_clk50M <= 1'b1;
    else reset_of_clk50M <= 1'b0;
  end

  always_ff @(posedge clk_20M or negedge locked) begin
    if (~locked) reset_of_clk20M <= 1'b1;
    else reset_of_clk20M <= 1'b0;
  end


 
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  // ?????????????????dpy1 ???
  // p=dpy0[0] // ---a---
  // c=dpy0[1] // |     |
  // d=dpy0[2] // f     b
  // e=dpy0[3] // |     |
  // b=dpy0[4] // ---g---
  // a=dpy0[5] // |     |
  // f=dpy0[6] // e     c
  // g=dpy0[7] // |     |
  //           // ---d---  p

  // // 7 ???????????????????? number ?? 16 ??????????????????
  // logic [7:0] number;
  // SEG7_LUT segL (
  //     .oSEG1(dpy0),
  //     .iDIG (number[3:0])
  // );  // dpy0 ???��?????
  // SEG7_LUT segH (
  //     .oSEG1(dpy1),
  //     .iDIG (number[7:4])
  // );  // dpy1 ???��?????

  // logic [15:0] led_bits;
  // assign leds = led_bits;

  // always_ff @(posedge push_btn or posedge reset_btn) begin
  //   if (reset_btn) begin  // ??��????????? LED ?????
  //     led_bits <= 16'h1;
  //   end else begin  // ?????��???????LED ???????
  //     led_bits <= {led_bits[14:0], led_bits[15]};
  //   end
  // end

 

  // // ???????????????? 800x600@72Hz?????????? 50MHz
  // logic [11:0] hdata;
  // assign video_red   = hdata < 266 ? 3'b111 : 0;  // ???????
  // assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0;  // ???????
  // assign video_blue  = hdata >= 532 ? 2'b11 : 0;  // ???????
  // assign video_clk   = clk_50M;
  // vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at72 (
  //     .clk        (clk_50M),
  //     .hdata      (hdata),        // ??????
  //     .vdata      (),             // ??????
  //     .hsync      (video_hsync),
  //     .vsync      (video_vsync),
  //     .data_enable(video_de)
  // );
  /* =========== Demo code end =========== */

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_50M;
  assign sys_rst = reset_of_clk50M;

  // wishbone_master_0
  logic wbm0_cyc_o;
  logic wbm0_stb_o;
  logic wbm0_ack_i;
  logic [31:0] wbm0_adr_o;
  logic [31:0] wbm0_dat_i;
  logic [31:0] wbm0_dat_o;
  logic [3:0] wbm0_sel_o;
  logic wbm0_we_o;

  // wishbone_master_1
  logic wbm1_cyc_o;
  logic wbm1_stb_o;
  logic wbm1_ack_i;
  logic [31:0] wbm1_adr_o;
  logic [31:0] wbm1_dat_i;
  logic [31:0] wbm1_dat_o;
  logic [3:0] wbm1_sel_o;
  logic wbm1_we_o;


  // Pipeline.sv
  pipeline #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
  ) pipeline_u (
    .clk_i(sys_clk),
    .rst_i(sys_rst),

    // wishbone master0
    .wb0_cyc_o(wbm0_cyc_o),
    .wb0_stb_o(wbm0_stb_o),
    .wb0_ack_i(wbm0_ack_i),
    .wb0_adr_o(wbm0_adr_o),
    .wb0_dat_i(wbm0_dat_i),
    .wb0_dat_o(wbm0_dat_o),
    .wb0_sel_o(wbm0_sel_o),
    .wb0_we_o(wbm0_we_o),

    // wishbone master1
    .wb1_cyc_o(wbm1_cyc_o),
    .wb1_stb_o(wbm1_stb_o),
    .wb1_ack_i(wbm1_ack_i),
    .wb1_adr_o(wbm1_adr_o),
    .wb1_dat_i(wbm1_dat_i),
    .wb1_dat_o(wbm1_dat_o),
    .wb1_sel_o(wbm1_sel_o),
    .wb1_we_o(wbm1_we_o)
    
  );
  logic wbm0_err_o;
  logic wbm0_rty_o;
  logic wbm1_err_o;
  logic wbm1_rty_o;


  logic [31:0] wbm_adr_o;
  logic [31:0] wbm_dat_i;
  logic [31:0] wbm_dat_o;
  logic wbm_we_o;
  logic [3:0] wbm_sel_o;
  logic wbm_stb_o;
  logic wbm_ack_i;
  logic wbm_err_i;
  logic wbm_rty_o;
  logic wbm_cyc_o;


  // wb_arbiter_2.v
  wb_arbiter_2 wb_arbiter_2 (
    .clk(sys_clk),
    .rst(sys_rst),

    .wbm0_adr_i(wbm0_adr_o),
    .wbm0_dat_i(wbm0_dat_o),
    .wbm0_dat_o(wbm0_dat_i),
    .wbm0_we_i(wbm0_we_o),
    .wbm0_sel_i(wbm0_sel_o),
    .wbm0_stb_i(wbm0_stb_o),
    .wbm0_ack_o(wbm0_ack_i),
    .wbm0_err_o(), // ?
    .wbm0_rty_o(), // ?
    .wbm0_cyc_i(wbm0_cyc_o),

    .wbm1_adr_i(wbm1_adr_o),
    .wbm1_dat_i(wbm1_dat_o),
    .wbm1_dat_o(wbm1_dat_i),
    .wbm1_we_i(wbm1_we_o),
    .wbm1_sel_i(wbm1_sel_o),
    .wbm1_stb_i(wbm1_stb_o),
    .wbm1_ack_o(wbm1_ack_i),
    .wbm1_err_o(), // ?
    .wbm1_rty_o(), // ?
    .wbm1_cyc_i(wbm1_cyc_o),

    .wbs_adr_o(wbm_adr_o),
    .wbs_dat_i(wbm_dat_i),
    .wbs_dat_o(wbm_dat_o),
    .wbs_we_o(wbm_we_o),
    .wbs_sel_o(wbm_sel_o),
    .wbs_stb_o(wbm_stb_o),
    .wbs_ack_i(wbm_ack_i),
    .wbs_err_i('0),
    .wbs_rty_i('0),
    .wbs_cyc_o(wbm_cyc_o)

  );

    /* =========== Lab5 MUX begin =========== */
  // Wishbone MUX (Masters) => bus slaves
  logic wbs0_cyc_o;
  logic wbs0_stb_o;
  logic wbs0_ack_i;
  logic [31:0] wbs0_adr_o;
  logic [31:0] wbs0_dat_o;
  logic [31:0] wbs0_dat_i;
  logic [3:0] wbs0_sel_o;
  logic wbs0_we_o;

  logic wbs1_cyc_o;
  logic wbs1_stb_o;
  logic wbs1_ack_i;
  logic [31:0] wbs1_adr_o;
  logic [31:0] wbs1_dat_o;
  logic [31:0] wbs1_dat_i;
  logic [3:0] wbs1_sel_o;
  logic wbs1_we_o;

  logic wbs2_cyc_o;
  logic wbs2_stb_o;
  logic wbs2_ack_i;
  logic [31:0] wbs2_adr_o;
  logic [31:0] wbs2_dat_o;
  logic [31:0] wbs2_dat_i;
  logic [3:0] wbs2_sel_o;
  logic wbs2_we_o;

  wb_mux_3 wb_mux (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master interface (to Lab5 master)
      .wbm_adr_i(wbm_adr_o),
      .wbm_dat_i(wbm_dat_o),
      .wbm_dat_o(wbm_dat_i),
      .wbm_we_i (wbm_we_o),
      .wbm_sel_i(wbm_sel_o),
      .wbm_stb_i(wbm_stb_o),
      .wbm_ack_o(wbm_ack_i),
      .wbm_err_o(),
      .wbm_rty_o(),
      .wbm_cyc_i(wbm_cyc_o),

      // Slave interface 0 (to BaseRAM controller)
      // Address range: 0x8000_0000 ~ 0x803F_FFFF
      .wbs0_addr    (32'h8000_0000),
      .wbs0_addr_msk(32'hFFC0_0000),

      .wbs0_adr_o(wbs0_adr_o),
      .wbs0_dat_i(wbs0_dat_i),
      .wbs0_dat_o(wbs0_dat_o),
      .wbs0_we_o (wbs0_we_o),
      .wbs0_sel_o(wbs0_sel_o),
      .wbs0_stb_o(wbs0_stb_o),
      .wbs0_ack_i(wbs0_ack_i),
      .wbs0_err_i('0),
      .wbs0_rty_i('0),
      .wbs0_cyc_o(wbs0_cyc_o),

      // Slave interface 1 (to ExtRAM controller)
      // Address range: 0x8040_0000 ~ 0x807F_FFFF
      .wbs1_addr    (32'h8040_0000),
      .wbs1_addr_msk(32'hFFC0_0000),

      .wbs1_adr_o(wbs1_adr_o),
      .wbs1_dat_i(wbs1_dat_i),
      .wbs1_dat_o(wbs1_dat_o),
      .wbs1_we_o (wbs1_we_o),
      .wbs1_sel_o(wbs1_sel_o),
      .wbs1_stb_o(wbs1_stb_o),
      .wbs1_ack_i(wbs1_ack_i),
      .wbs1_err_i('0),
      .wbs1_rty_i('0),
      .wbs1_cyc_o(wbs1_cyc_o),

      // Slave interface 2 (to UART controller)
      // Address range: 0x1000_0000 ~ 0x1000_FFFF
      .wbs2_addr    (32'h1000_0000),
      .wbs2_addr_msk(32'hFFFF_0000),

      .wbs2_adr_o(wbs2_adr_o),
      .wbs2_dat_i(wbs2_dat_i),
      .wbs2_dat_o(wbs2_dat_o),
      .wbs2_we_o (wbs2_we_o),
      .wbs2_sel_o(wbs2_sel_o),
      .wbs2_stb_o(wbs2_stb_o),
      .wbs2_ack_i(wbs2_ack_i),
      .wbs2_err_i('0),
      .wbs2_rty_i('0),
      .wbs2_cyc_o(wbs2_cyc_o)
  );

  /* ===========  MUX end =========== */

  /* =========== Slaves begin =========== */
  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_base (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs0_cyc_o),
      .wb_stb_i(wbs0_stb_o),
      .wb_ack_o(wbs0_ack_i),
      .wb_adr_i(wbs0_adr_o),
      .wb_dat_i(wbs0_dat_o),
      .wb_dat_o(wbs0_dat_i),
      .wb_sel_i(wbs0_sel_o),
      .wb_we_i (wbs0_we_o),

      // To SRAM chip
      .sram_addr(base_ram_addr),
      .sram_data(base_ram_data),
      .sram_ce_n(base_ram_ce_n),
      .sram_oe_n(base_ram_oe_n),
      .sram_we_n(base_ram_we_n),
      .sram_be_n(base_ram_be_n)
  );

  sram_controller #(
      .SRAM_ADDR_WIDTH(20),
      .SRAM_DATA_WIDTH(32)
  ) sram_controller_ext (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs1_cyc_o),
      .wb_stb_i(wbs1_stb_o),
      .wb_ack_o(wbs1_ack_i),
      .wb_adr_i(wbs1_adr_o),
      .wb_dat_i(wbs1_dat_o),
      .wb_dat_o(wbs1_dat_i),
      .wb_sel_i(wbs1_sel_o),
      .wb_we_i (wbs1_we_o),

      // To SRAM chip
      .sram_addr(ext_ram_addr),
      .sram_data(ext_ram_data),
      .sram_ce_n(ext_ram_ce_n),
      .sram_oe_n(ext_ram_oe_n),
      .sram_we_n(ext_ram_we_n),
      .sram_be_n(ext_ram_be_n)
  );

  uart_controller #(
      .CLK_FREQ(50_000_000),
      .BAUD    (115200)
  ) uart_controller (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .wb_cyc_i(wbs2_cyc_o),
      .wb_stb_i(wbs2_stb_o),
      .wb_ack_o(wbs2_ack_i),
      .wb_adr_i(wbs2_adr_o),
      .wb_dat_i(wbs2_dat_o),
      .wb_dat_o(wbs2_dat_i),
      .wb_sel_i(wbs2_sel_o),
      .wb_we_i (wbs2_we_o),

      // to UART pins
      .uart_txd_o(txd),
      .uart_rxd_i(rxd)
  );






endmodule
