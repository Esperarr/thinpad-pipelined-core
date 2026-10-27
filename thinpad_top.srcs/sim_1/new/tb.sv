`timescale 1ns / 1ps

module tb;

  wire clk_50M;
  wire clk_11M0592;

  reg push_btn;
  reg reset_btn;
  reg [3:0] touch_btn;
  reg [31:0] dip_sw;

  wire [15:0] leds;
  wire [7:0] dpy0;
  wire [7:0] dpy1;

  wire txd;
  wire rxd;

  wire [31:0] base_ram_data;
  wire [19:0] base_ram_addr;
  wire [3:0] base_ram_be_n;
  wire base_ram_ce_n;
  wire base_ram_oe_n;
  wire base_ram_we_n;

  wire [31:0] ext_ram_data;
  wire [19:0] ext_ram_addr;
  wire [3:0] ext_ram_be_n;
  wire ext_ram_ce_n;
  wire ext_ram_oe_n;
  wire ext_ram_we_n;

  wire [22:0] flash_a;
  wire [15:0] flash_d;
  wire flash_rp_n;
  wire flash_vpen;
  wire flash_ce_n;
  wire flash_oe_n;
  wire flash_we_n;
  wire flash_byte_n;

  wire uart_rdn;
  wire uart_wrn;
  wire uart_dataready;
  wire uart_tbre;
  wire uart_tsre;

  // The monitor image is kept inside the repository for reproducible setup.
  parameter BASE_RAM_INIT_FILE =
      "thinpad_top.srcs/sim_1/new/testcase/kernel.bin";
  parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";
  parameter FLASH_INIT_FILE = "/tmp/kernel.elf";

  initial begin
    dip_sw = 32'h2;
    touch_btn = 0;
    reset_btn = 0;
    push_btn = 0;

    #100;
    reset_btn = 1;
    #100;
    reset_btn = 0;

    #10_000_000;
    $finish;
  end

  thinpad_top dut (
      .clk_50M(clk_50M),
      .clk_11M0592(clk_11M0592),
      .push_btn(push_btn),
      .reset_btn(reset_btn),
      .touch_btn(touch_btn),
      .dip_sw(dip_sw),
      .leds(leds),
      .dpy1(dpy1),
      .dpy0(dpy0),
      .txd(txd),
      .rxd(rxd),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .base_ram_data(base_ram_data),
      .base_ram_addr(base_ram_addr),
      .base_ram_ce_n(base_ram_ce_n),
      .base_ram_oe_n(base_ram_oe_n),
      .base_ram_we_n(base_ram_we_n),
      .base_ram_be_n(base_ram_be_n),
      .ext_ram_data(ext_ram_data),
      .ext_ram_addr(ext_ram_addr),
      .ext_ram_ce_n(ext_ram_ce_n),
      .ext_ram_oe_n(ext_ram_oe_n),
      .ext_ram_we_n(ext_ram_we_n),
      .ext_ram_be_n(ext_ram_be_n),
      .flash_d(flash_d),
      .flash_a(flash_a),
      .flash_rp_n(flash_rp_n),
      .flash_vpen(flash_vpen),
      .flash_oe_n(flash_oe_n),
      .flash_ce_n(flash_ce_n),
      .flash_byte_n(flash_byte_n),
      .flash_we_n(flash_we_n)
  );

  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M(clk_50M)
  );

  cpld_model cpld (
      .clk_uart(clk_11M0592),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .data(base_ram_data[7:0])
  );

  uart_model uart (
      .rxd(txd),
      .txd(rxd)
  );

  sram_model base1 (
      .DataIO(base_ram_data[15:0]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[0]),
      .UB_n(base_ram_be_n[1])
  );

  sram_model base2 (
      .DataIO(base_ram_data[31:16]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[2]),
      .UB_n(base_ram_be_n[3])
  );

  sram_model ext1 (
      .DataIO(ext_ram_data[15:0]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[0]),
      .UB_n(ext_ram_be_n[1])
  );

  sram_model ext2 (
      .DataIO(ext_ram_data[31:16]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[2]),
      .UB_n(ext_ram_be_n[3])
  );

  x28fxxxp30 #(
      .FILENAME_MEM(FLASH_INIT_FILE)
  ) flash (
      .A(flash_a[1+:22]),
      .DQ(flash_d),
      .W_N(flash_we_n),
      .G_N(flash_oe_n),
      .E_N(flash_ce_n),
      .L_N(1'b0),
      .K(1'b0),
      .WP_N(flash_vpen),
      .RP_N(flash_rp_n),
      .VDD('d3300),
      .VDDQ('d3300),
      .VPP('d1800),
      .Info(1'b1)
  );

  initial begin
    wait (flash_byte_n == 1'b0);
    $display("8-bit Flash interface is not supported in simulation.");
    $display("Please tie flash_byte_n high.");
    $stop;
  end

  initial begin : load_base_ram
    reg [31:0] image[0:1048575];
    integer fd;
    integer image_bytes;

    fd = $fopen(BASE_RAM_INIT_FILE, "rb");
    if (!fd) begin
      $display("Failed to open %s", BASE_RAM_INIT_FILE);
    end else begin
      image_bytes = $fread(image, fd);
      $fclose(fd);
      image_bytes = image_bytes / 4;
      $display("BaseRAM image loaded: %0d words", image_bytes);
      for (integer i = 0; i < image_bytes; i = i + 1) begin
        base1.mem_array0[i] = image[i][24+:8];
        base1.mem_array1[i] = image[i][16+:8];
        base2.mem_array0[i] = image[i][8+:8];
        base2.mem_array1[i] = image[i][0+:8];
      end
    end
  end

  initial begin : load_ext_ram
    reg [31:0] image[0:1048575];
    integer fd;
    integer image_bytes;

    fd = $fopen(EXT_RAM_INIT_FILE, "rb");
    if (!fd) begin
      $display("Optional ExtRAM image not found: %s", EXT_RAM_INIT_FILE);
    end else begin
      image_bytes = $fread(image, fd);
      $fclose(fd);
      image_bytes = image_bytes / 4;
      $display("ExtRAM image loaded: %0d words", image_bytes);
      for (integer i = 0; i < image_bytes; i = i + 1) begin
        ext1.mem_array0[i] = image[i][24+:8];
        ext1.mem_array1[i] = image[i][16+:8];
        ext2.mem_array0[i] = image[i][8+:8];
        ext2.mem_array1[i] = image[i][0+:8];
      end
    end
  end

endmodule
