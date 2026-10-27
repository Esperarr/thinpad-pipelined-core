module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i, // 32λ��ַ ��λ���ֽ�
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i, // 3:0
    input wire wb_we_i,

    // sram interface
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr, // 20λ��ַ ��λ�����ֽ�
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output reg sram_ce_n,
    output reg sram_oe_n,
    output reg sram_we_n,
    output reg [SRAM_BYTES-1:0] sram_be_n // 3:0
);
  typedef enum logic [2:0] {
    ST_IDLE = 0,
    ST_READ = 1,
    ST_READ_2 = 2,
    ST_WRITE = 3,
    ST_WRITE_2 = 4,
    ST_WRITE_3 = 5,
    ST_DONE = 6
  } state_t;

  state_t state;
  wire [31:0] sram_data_i_comb;
  reg [31:0] sram_data_o_reg = 32'b0;
  reg [31:0] calc_addr;
  
  reg sram_data_t_reg = 1'b1;

  assign sram_data = sram_data_t_reg ? 32'bz : sram_data_o_reg;
  assign sram_data_i_comb = sram_data;
  // ����? signal_t = 0�� signal_o Ϊ���?? д
  // ����ʱ signal_t = 1�� signal_i Ϊ���� ��


  always_ff @(posedge clk_i or posedge rst_i) begin
    if(rst_i) begin
      sram_data_t_reg <= 1'b1;
      sram_data_o_reg <= 32'b0;
      sram_addr <= 20'b0;


      sram_ce_n <= 1'b1;
      sram_oe_n <= 1'b1;
      sram_we_n <= 1'b1;
      sram_be_n <= 4'b0000;

      wb_ack_o <= 1'b0;

      state <= ST_IDLE;
    end else begin
      case(state)
        ST_IDLE: begin
          // ��ʼ״̬
          if(wb_cyc_i && wb_stb_i) begin
            if(wb_we_i) begin
              sram_data_t_reg <= 1'b0;
              sram_data_o_reg <= wb_dat_i;

              sram_addr <= wb_adr_i[SRAM_ADDR_WIDTH+1:2];
              
              sram_ce_n <= 0;
              sram_oe_n <= 1;
              sram_we_n <= 1;
              sram_be_n <= ~wb_sel_i;

              state <= ST_WRITE;
            end else begin
              sram_data_t_reg <= 1'b1;
              sram_addr <= wb_adr_i[SRAM_ADDR_WIDTH+1:2];
              
              sram_ce_n <= 0;
              sram_oe_n <= 0;
              sram_we_n <= 1;
              sram_be_n <= ~wb_sel_i;

              state <= ST_READ;
            end
          end
        end
        ST_READ: begin
          state <= ST_READ_2;
        end
        ST_READ_2: begin
          wb_dat_o <= sram_data_i_comb;
          
          wb_ack_o <= 1;
          sram_ce_n <= 1;
          sram_oe_n <= 1;
          state <= ST_DONE;
        end
        ST_WRITE: begin
          sram_we_n <= 0;
          state <= ST_WRITE_2;
        end
        ST_WRITE_2: begin
          sram_we_n <= 1;
          state <= ST_WRITE_3;
        end
        ST_WRITE_3: begin
          wb_ack_o <= 1;
          sram_ce_n <= 1;
          state <= ST_DONE;
        end
        ST_DONE: begin
          wb_ack_o <= 0;
          state <= ST_IDLE;
        end
      endcase
    end
  end


endmodule
